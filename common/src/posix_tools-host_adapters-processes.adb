with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Hostkit;
with Hostkit.Fs;
with Hostkit.Process;
with Posix_Tools.Host_Adapters.Environment;

package body Posix_Tools.Host_Adapters.Processes is
   Max_Captured_Bytes : constant Natural := 1_048_576;

   function Equal_Position (Text : String) return Natural is
   begin
      for I in Text'Range loop
         if Text (I) = '=' then
            return I;
         end if;
      end loop;
      return 0;
   end Equal_Position;

   function To_Host_Arguments (Arguments : Posix_Tools.Arguments.Vector) return Hostkit.String_Vectors.Vector is
      use Ada.Strings.Unbounded;
      Result : Hostkit.String_Vectors.Vector;
   begin
      for I in 1 .. Natural (Arguments.Length) loop
         Result.Append (To_Unbounded_String (Arguments.Element (I)));
      end loop;
      return Result;
   end To_Host_Arguments;

   function Read_Text_File (Path : String; Max_Bytes : Natural) return String is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;

      File : File_Type;
   begin
      if Path = "" or else not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Open (File, In_File, Path);
      declare
         Size  : constant Stream_IO.Count := Ada.Streams.Stream_IO.Size (File);
         Limit : constant Stream_IO.Count :=
           Stream_IO.Count'Min (Size, Stream_IO.Count (Max_Bytes));
         Data  : Stream_Element_Array (1 .. Stream_Element_Offset (Limit));
         Last  : Stream_Element_Offset;
         Text  : String (1 .. Natural (Limit));
      begin
         if Limit = 0 then
            Close (File);
            return "";
         end if;

         Read (File, Data, Last);
         Close (File);

         for I in 1 .. Natural (Last) loop
            Text (I) := Character'Val (Data (Stream_Element_Offset (I)));
         end loop;

         return Text (1 .. Natural (Last));
      end;
   exception
      when others =>
         if Is_Open (File) then
            Close (File);
         end if;
         return "";
   end Read_Text_File;

   procedure Clear_Pairs (Pairs : Posix_Tools.Arguments.Vector) is
   begin
      for I in 1 .. Natural (Pairs.Length) loop
         declare
            Pair  : constant String := Pairs.Element (I);
            Equal : constant Natural := Equal_Position (Pair);
         begin
            if Equal > Pair'First then
               Ada.Environment_Variables.Clear (Pair (Pair'First .. Equal - 1));
            end if;
         end;
      end loop;
   end Clear_Pairs;

   procedure Set_Pairs (Pairs : Posix_Tools.Arguments.Vector) is
   begin
      for I in 1 .. Natural (Pairs.Length) loop
         declare
            Pair  : constant String := Pairs.Element (I);
            Equal : constant Natural := Equal_Position (Pair);
         begin
            if Equal > Pair'First then
               Ada.Environment_Variables.Set (Pair (Pair'First .. Equal - 1), Pair (Equal + 1 .. Pair'Last));
            end if;
         end;
      end loop;
   end Set_Pairs;

   function Run
     (Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean
   is
      Program : constant String := Hostkit.Process.Locate (Utility);
      Host_Arguments : constant Hostkit.String_Vectors.Vector := To_Host_Arguments (Arguments);
   begin
      if Program = "" then
         Exit_Status := 127;
         return False;
      end if;
      if Hostkit.Process.Run (Program, Host_Arguments, Exit_Status) then
         return True;
      end if;

      Exit_Status := 126;
      return False;
   end Run;

   function Run_With_Environment
     (Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Environment : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean
   is
      Original : constant Posix_Tools.Arguments.Vector := Posix_Tools.Host_Adapters.Environment.Pairs;
      Started  : Boolean := False;
   begin
      Clear_Pairs (Original);
      Set_Pairs (Environment);
      Started := Run (Utility, Arguments, Exit_Status);
      Clear_Pairs (Environment);
      Set_Pairs (Original);
      return Started;
   exception
      when others =>
         Clear_Pairs (Environment);
         Set_Pairs (Original);
         Exit_Status := 125;
      return False;
   end Run_With_Environment;

   function Run_With_Timeout
     (Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Timeout_Ms  : Natural;
      Exit_Status : out Integer;
      Timed_Out   : out Boolean;
      Output      : out Ada.Strings.Unbounded.Unbounded_String;
      Error       : out Ada.Strings.Unbounded.Unbounded_String) return Boolean
   is
      use Ada.Strings.Unbounded;

      Program : constant String := Hostkit.Process.Locate (Utility);
      Host_Arguments : constant Hostkit.String_Vectors.Vector := To_Host_Arguments (Arguments);
      Temp : Unbounded_String;
   begin
      Output := Null_Unbounded_String;
      Error := Null_Unbounded_String;
      Timed_Out := False;

      if Program = "" then
         Exit_Status := 127;
         return False;
      end if;

      Temp := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("posix-tools-timeout"));
      if To_String (Temp) = "" then
         Exit_Status := 126;
         return False;
      end if;

      declare
         Temp_Path : constant String := To_String (Temp);
         Out_Path  : constant String := Hostkit.Fs.Join (Temp_Path, "stdout");
         Err_Path  : constant String := Hostkit.Fs.Join (Temp_Path, "stderr");
         Outcome   : constant Hostkit.Process.Process_Outcome :=
           Hostkit.Process.Run_Captured
             (Program     => Program,
              Arguments   => Host_Arguments,
              Stdout_Path => Out_Path,
              Stderr_Path => Err_Path,
              Timeout_Ms  => Timeout_Ms);
      begin
         Output := To_Unbounded_String (Read_Text_File (Out_Path, Max_Captured_Bytes));
         Error := To_Unbounded_String (Read_Text_File (Err_Path, Max_Captured_Bytes));

         if Ada.Directories.Exists (Temp_Path) then
            Ada.Directories.Delete_Tree (Temp_Path);
         end if;

         Timed_Out := Outcome.Timed_Out;
         Exit_Status := Outcome.Exit_Status;
         if not Outcome.Started then
            Exit_Status := 126;
         end if;
         return Outcome.Started;
      end;
   exception
      when others =>
         if Length (Temp) > 0 and then Ada.Directories.Exists (To_String (Temp)) then
            Ada.Directories.Delete_Tree (To_String (Temp));
         end if;
         Output := Null_Unbounded_String;
         Error := Null_Unbounded_String;
         Timed_Out := False;
         Exit_Status := 125;
         return False;
   end Run_With_Timeout;
end Posix_Tools.Host_Adapters.Processes;
