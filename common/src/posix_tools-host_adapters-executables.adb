with Ada.Calendar;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Streams;
with Hostkit;
with Hostkit.Descriptors;
with Hostkit.Fs;
with Hostkit.Process;
with Posix_Tools.Text.Matching;

package body Posix_Tools.Host_Adapters.Executables is
   Excessive_Output : constant String := "posix-tools-excessive-identity-output";
   Max_Identity_Output_Bytes : constant := 4096;

   function Is_Wrong_Version_Output (Text : String; Prefix : String) return Boolean is
      LF : constant Character := Character'Val (10);
   begin
      if not Posix_Tools.Text.Matching.Starts_With (Text, Prefix)
        or else Text'Length <= Prefix'Length
        or else Text (Text'Last) /= LF
      then
         return False;
      end if;

      for I in Text'First + Prefix'Length .. Text'Last - 1 loop
         if Text (I) = LF then
            return False;
         end if;
      end loop;

      return True;
   end Is_Wrong_Version_Output;

   function Capture_Leaf (Directory : String; Label : String) return String is
      type Word_64 is mod 2 ** 64;

      Hash : Word_64 := 14_695_981_039_346_656_037;

      procedure Mix (Text : String) is
      begin
         for Ch of Text loop
            Hash := (Hash xor Word_64 (Character'Pos (Ch))) * 1_099_511_628_211;
         end loop;
      end Mix;

      function Hex_Image return String is
         Hex_Digits : constant String := "0123456789abcdef";
         Value      : Word_64 := Hash;
         Result     : String (1 .. 16);
      begin
         for I in reverse Result'Range loop
            Result (I) := Hex_Digits (Hex_Digits'First + Natural (Value mod 16));
            Value := Value / 16;
         end loop;

         return Result;
      end Hex_Image;
   begin
      Mix (Directory);
      Mix (Label);
      Mix (Duration'Image (Ada.Calendar.Seconds (Ada.Calendar.Clock)));
      return Label & "-" & Hex_Image & ".capture";
   end Capture_Leaf;

   function Locate (Executable : String) return String is
   begin
      return Hostkit.Process.Locate (Executable);
   end Locate;

   function Normal_Path (Path : String) return String is
      Real : constant String := Hostkit.Fs.Real_Path (Path);
   begin
      return (if Real = "" then Path else Real);
   exception
      when others =>
         return Path;
   end Normal_Path;

   function Same_Path (Left : String; Right : String) return Boolean is
   begin
      return Left = Right or else Normal_Path (Left) = Normal_Path (Right);
   end Same_Path;

   function Sibling_Command_Path (Executable : String) return String is
      Directory : constant String := Hostkit.Fs.Own_Executable_Directory;
   begin
      if Directory = "" then
         return "";
      end if;

      declare
         Plain_Path : constant String := Hostkit.Fs.Join (Directory, Executable);
         Exe_Path   : constant String := Plain_Path & ".exe";
      begin
         if Hostkit.Fs.Is_Executable (Plain_Path) then
            return Plain_Path;
         elsif Hostkit.Fs.Is_Executable (Exe_Path) then
            return Exe_Path;
         else
            return "";
         end if;
      end;
   exception
      when others =>
         return "";
   end Sibling_Command_Path;

   function Read_Text_File (Path : String; Max_Bytes : Natural) return String is
      use Ada.Strings.Unbounded;

      use type Ada.Streams.Stream_Element_Offset;

      File   : Hostkit.Descriptors.Descriptor := Hostkit.Descriptors.Invalid;
      Result : Unbounded_String;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 256);
      Last   : Ada.Streams.Stream_Element_Offset;

      function Buffer_Text return String is
         Text : String (1 .. Natural (Last - Buffer'First + 1));
      begin
         for Index in Text'Range loop
            Text (Index) :=
              Character'Val
                (Buffer
                   (Buffer'First
                    + Ada.Streams.Stream_Element_Offset (Index - Text'First)));
         end loop;

         return Text;
      end Buffer_Text;
   begin
      if not Hostkit.Descriptors.Open_File (Path, Hostkit.Descriptors.Open_Read, File) then
         return "";
      end if;

      loop
         case Hostkit.Descriptors.Read (File, Buffer, Last) is
            when Hostkit.Descriptors.Transfer_Ok =>
               if Last >= Buffer'First then
                  if Length (Result) + Natural (Last - Buffer'First + 1) > Max_Bytes then
                     Hostkit.Descriptors.Close (File);
                     return Excessive_Output;
                  end if;

                  Append (Result, Buffer_Text);
               end if;

            when Hostkit.Descriptors.Transfer_Interrupted =>
               null;

            when Hostkit.Descriptors.Transfer_End_Of_File =>
               exit;

            when others =>
               Hostkit.Descriptors.Close (File);
               return "";
         end case;
      end loop;

      Hostkit.Descriptors.Close (File);
      return To_String (Result);
   exception
      when others =>
         Hostkit.Descriptors.Close (File);
         return "";
   end Read_Text_File;

   function Verify_Identity
     (Executable : String;
      Expected_Version : String := Posix_Tools.Version.Version_String) return String
   is
      Located : constant String := Hostkit.Process.Locate (Executable);
      Sibling : constant String := Sibling_Command_Path (Executable);
   begin
      if Located /= ""
        and then Sibling /= ""
        and then not Same_Path (Located, Sibling)
        and then Verify_Identity_At_Path (Executable, Sibling, Expected_Version) = "ok"
      then
         return "shadowed";
      end if;

      return Verify_Identity_At_Path (Executable, Located, Expected_Version);
   end Verify_Identity;

   function Verify_Identity_At_Path
     (Executable : String;
      Path       : String;
      Expected_Version : String := Posix_Tools.Version.Version_String) return String
   is
      use Ada.Strings.Unbounded;
      Args    : Hostkit.String_Vectors.Vector;
      Temp    : Unbounded_String;
   begin
      if Path = "" then
         return "missing";
      elsif not Hostkit.Fs.Is_Executable (Path) then
         return "not executable";
      end if;

      Temp := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("posix-tools-verify"));
      if To_String (Temp) = "" then
         return "unverifiable";
      end if;

      Args.Append (To_Unbounded_String ("--posix-tools-identify"));

      declare
         Temp_Path : constant String := To_String (Temp);
         Out_Path  : constant String := Hostkit.Fs.Join (Temp_Path, Capture_Leaf (Temp_Path, "stdout"));
         Err_Path  : constant String := Hostkit.Fs.Join (Temp_Path, Capture_Leaf (Temp_Path, "stderr"));
         Outcome  : constant Hostkit.Process.Process_Outcome :=
           Hostkit.Process.Run_Captured
             (Program     => Path,
              Arguments   => Args,
              Stdout_Path => Out_Path,
              Stderr_Path => Err_Path,
              Timeout_Ms  => 2000);
         Output   : constant String := Read_Text_File (Out_Path, Max_Identity_Output_Bytes);
         Error    : constant String := Read_Text_File (Err_Path, Max_Identity_Output_Bytes);
         LF       : constant Character := Character'Val (10);
         Version_Prefix : constant String :=
           "schema=1" & LF
           & "project=posix-tools" & LF
           & "command=" & Executable & LF
           & "version=";
         Expected_Output : constant String := Version_Prefix & Expected_Version & LF;
      begin
         if Ada.Directories.Exists (To_String (Temp)) then
            Ada.Directories.Delete_Tree (To_String (Temp));
         end if;

         if not Outcome.Started or else Outcome.Timed_Out then
            return "unverifiable";
         elsif Output = Excessive_Output or else Error = Excessive_Output then
            return "wrong project";
         elsif Error /= "" then
            return "wrong project";
         elsif Output = Expected_Output then
            return "ok";
         elsif Is_Wrong_Version_Output (Output, Version_Prefix) then
            return "wrong version";
         elsif Outcome.Exit_Status /= 0 then
            return "wrong project";
         else
            return "wrong project";
         end if;
      end;
   exception
      when others =>
         if To_String (Temp) /= "" and then Ada.Directories.Exists (To_String (Temp)) then
            Ada.Directories.Delete_Tree (To_String (Temp));
         end if;
         return "unverifiable";
   end Verify_Identity_At_Path;
end Posix_Tools.Host_Adapters.Executables;
