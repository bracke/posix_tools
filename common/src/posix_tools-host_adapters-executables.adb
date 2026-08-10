with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Hostkit;
with Hostkit.Fs;
with Hostkit.Process;

package body Posix_Tools.Host_Adapters.Executables is
   Excessive_Output : constant String := "posix-tools-excessive-identity-output";
   Max_Identity_Output_Bytes : constant := 4096;

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      if Pattern = "" then
         return True;
      elsif Text'Length < Pattern'Length then
         return False;
      end if;

      for I in Text'First .. Text'Last - Pattern'Length + 1 loop
         if Text (I .. I + Pattern'Length - 1) = Pattern then
            return True;
         end if;
      end loop;

      return False;
   end Contains;

   function Locate (Executable : String) return String is
   begin
      return Hostkit.Process.Locate (Executable);
   end Locate;

   function Read_Text_File (Path : String; Max_Bytes : Natural) return String is
      use Ada.Strings.Unbounded;
      File      : Ada.Text_IO.File_Type;
      Result    : Unbounded_String;
      Line      : String (1 .. 256);
      Last      : Natural;
      Remaining : Natural := Max_Bytes;

      procedure Append_Bounded (Text : String) is
      begin
         if Text'Length > Remaining then
            Result := To_Unbounded_String (Excessive_Output);
            Remaining := 0;
         else
            Append (Result, Text);
            Remaining := Remaining - Text'Length;
         end if;
      end Append_Bounded;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         if Last >= Line'First then
            Append_Bounded (Line (Line'First .. Last));
         end if;

         exit when Remaining = 0;

         if Last < Line'Last then
            Append_Bounded ("" & Character'Val (10));
         end if;

         exit when Remaining = 0;
      end loop;
      Ada.Text_IO.Close (File);
      return To_String (Result);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Read_Text_File;

   function Verify_Identity
     (Executable : String;
      Expected_Version : String := Posix_Tools.Version.Version_String) return String
   is
      Located : constant String := Hostkit.Process.Locate (Executable);
   begin
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
         Out_Path : constant String := Hostkit.Fs.Join (To_String (Temp), "stdout.txt");
         Err_Path : constant String := Hostkit.Fs.Join (To_String (Temp), "stderr.txt");
         Outcome  : constant Hostkit.Process.Process_Outcome :=
           Hostkit.Process.Run_Captured
             (Program     => Path,
              Arguments   => Args,
              Stdout_Path => Out_Path,
              Stderr_Path => Err_Path,
              Timeout_Ms  => 2000);
         Output   : constant String := Read_Text_File (Out_Path, Max_Identity_Output_Bytes);
         Error    : constant String := Read_Text_File (Err_Path, Max_Identity_Output_Bytes);
      begin
         if Ada.Directories.Exists (To_String (Temp)) then
            Ada.Directories.Delete_Tree (To_String (Temp));
         end if;

         if not Outcome.Started or else Outcome.Timed_Out then
            return "unverifiable";
         elsif Outcome.Exit_Status /= 0 then
            return "wrong project";
         elsif Output = Excessive_Output or else Error = Excessive_Output then
            return "wrong project";
         elsif Error /= "" then
            return "wrong project";
         elsif not Contains (Output, "schema=1" & Character'Val (10))
           or else not Contains (Output, "project=posix-tools" & Character'Val (10))
           or else not Contains (Output, "command=" & Executable & Character'Val (10))
         then
            return "wrong project";
         elsif not Contains (Output, "version=" & Expected_Version & Character'Val (10)) then
            return "wrong version";
         else
            return "ok";
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
