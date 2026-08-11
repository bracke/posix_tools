with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Basename;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Dirname;
with Posix_Tools.Commands.Echo;
with Posix_Tools.Commands.False_Command;
with Posix_Tools.Commands.Head;
with Posix_Tools.Commands.Pwd;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Root;
with Posix_Tools.Commands.Tail;
with Posix_Tools.Commands.True_Command;
with Posix_Tools.Commands.Wc;
with Posix_Tools.Exit_Status;
with Posix_Tools.Presentation;
with Posix_Tools.Version;
with Test_Contexts;

package body Command_Tests is
   use type Posix_Tools.Exit_Status.Code;

   function No_Args return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      return Result;
   end No_Args;

   function One_Arg (A : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      return Result;
   end One_Arg;

   function Two_Args (A, B : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      return Result;
   end Two_Args;

   function Three_Args (A, B, C : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      return Result;
   end Three_Args;

   function Four_Args (A, B, C, D : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      Result.Append (D);
      return Result;
   end Four_Args;

   function Five_Args (A, B, C, D, E : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      Result.Append (D);
      Result.Append (E);
      return Result;
   end Five_Args;

   function Fixture_Path (Name : String) return String is
   begin
      if Ada.Directories.Exists ("fixtures") then
         return "fixtures/" & Name;
      else
         return "../fixtures/" & Name;
      end if;
   end Fixture_Path;

   function Contains (Text, Pattern : String) return Boolean is
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

   procedure Write_File (Path, Data : String) is
      use type Ada.Streams.Stream_Element_Offset;
      File   : Ada.Streams.Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Data'Length));
      Target : Ada.Streams.Stream_Element_Offset := Buffer'First;
   begin
      if Data'Length = 0 then
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
         Ada.Streams.Stream_IO.Close (File);
         return;
      end if;

      for I in Data'Range loop
         Buffer (Target) := Ada.Streams.Stream_Element (Character'Pos (Data (I)));
         Target := Target + Ada.Streams.Stream_Element_Offset (1);
      end loop;

      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Ada.Streams.Stream_IO.Write (File, Buffer);
      Ada.Streams.Stream_IO.Close (File);
   end Write_File;

   procedure Test_Basename (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", ".txt"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "file" & Character'Val (10), "basename output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename status");
   end Test_Basename;

   procedure Test_Basename_Edge_Cases (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("basename", One_Arg (""));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "" & LF, "basename command empty");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename empty status");

      Context.Initialize ("basename", One_Arg ("///"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/" & LF, "basename command root");

      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", "file.txt"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file.txt" & LF,
         "basename suffix equal full name");

      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", ".bin"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file.txt" & LF,
         "basename suffix absent");

      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", ""));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file.txt" & LF,
         "basename empty suffix");

      Context.Initialize ("basename", One_Arg ("a//b///"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & LF,
         "basename trailing repeated slash");

      Context.Initialize
        ("basename",
         Two_Args
           ("dir/" & Character'Val (16#C3#) & Character'Val (16#A6#) & ".txt",
            ".txt"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#C3#) & Character'Val (16#A6#) & LF,
         "basename non-ASCII suffix");

      Context.Initialize ("basename", One_Arg ("a\b"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a\b" & LF, "basename command backslash");
   end Test_Basename_Edge_Cases;

   procedure Test_Cat_Files (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      First   : constant String := Fixture_Path ("reg-cat-first.bin");
      Second  : constant String := Fixture_Path ("reg-cat-second.bin");
   begin
      Write_File (First, "A" & Character'Val (0));
      Write_File (Second, "B");

      Context.Initialize ("cat", Two_Args (First, Second));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A" & Character'Val (0) & "B",
         "cat preserves ordered file bytes");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat files status");
   end Test_Cat_Files;

   procedure Test_Cat_Continues_After_Missing_File (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Missing : constant String := Fixture_Path ("missing-cat-file.bin");
      Later   : constant String := Fixture_Path ("reg-cat-later.bin");
   begin
      Write_File (Later, "later");

      Context.Initialize ("cat", Two_Args (Missing, Later));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "later", "cat continues after missing file");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "cat: '" & Missing & "': cannot read file" & Character'Val (10),
         "cat missing diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cat aggregate failure status");
   end Test_Cat_Continues_After_Missing_File;

   procedure Test_Cat_Standard_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "A" & Character'Val (0) & "B");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A" & Character'Val (0) & "B",
         "cat implicit stdin preserves bytes");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat implicit stdin status");

      Context.Initialize ("cat", Two_Args ("-", "-"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "cat repeated stdin does not rewind");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat repeated stdin status");

      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "cat stdin read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "cat: 'standard input': cannot read file" & Character'Val (10),
         "cat stdin read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cat stdin read failure status");

      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 3);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "cat stdin partial read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "cat: 'standard input': cannot read file" & Character'Val (10),
         "cat stdin partial read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cat stdin partial read failure status");
   end Test_Cat_Standard_Input;

   procedure Test_Cat_Byte_Preservation_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;

      Seed : Word_32 := 16#5054_0003#;

      function Next_Value return Word_32 is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Seed;
      end Next_Value;

      function Random_Natural (Modulo : Positive) return Natural is
      begin
         return Natural (Next_Value mod Word_32 (Modulo));
      end Random_Natural;

      function Generated_Bytes return String is
         Length : constant Natural := Random_Natural (513);
         Result : Ada.Strings.Unbounded.Unbounded_String;
      begin
         for I in 1 .. Length loop
            case Random_Natural (8) is
               when 0 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (0));
               when 1 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (10));
               when others =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (Random_Natural (256)));
            end case;
         end loop;

         return Ada.Strings.Unbounded.To_String (Result);
      end Generated_Bytes;
   begin
      for Case_Index in 1 .. 128 loop
         declare
            Context : Test_Contexts.Capturing_Context;
            Result  : Posix_Tools.Commands.Results.Result;
            Input   : constant String := Generated_Bytes;
            Label   : constant String := "seed 0x50540003 case" & Integer'Image (Case_Index);
         begin
            Context.Initialize ("cat", No_Args);
            Test_Contexts.Set_Standard_Input (Context, Input);
            Posix_Tools.Commands.Cat.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Input,
               "cat implicit stdin bytes for " & Label);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Context) = "",
               "cat implicit stdin stderr for " & Label);
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "cat implicit stdin status for " & Label);

            Context.Initialize ("cat", One_Arg ("-"));
            Test_Contexts.Set_Standard_Input (Context, Input);
            Posix_Tools.Commands.Cat.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Input,
               "cat explicit stdin bytes for " & Label);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Context) = "",
               "cat explicit stdin stderr for " & Label);
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "cat explicit stdin status for " & Label);
         end;
      end loop;
   end Test_Cat_Byte_Preservation_Property;

   procedure Test_Cat_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Output_Failure_After (Context, 3);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "cat partial output before failure");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "cat output failure has no read diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cat output failure status");
   end Test_Cat_Output_Failure;

   procedure Test_Dirname (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("dirname", One_Arg ("/tmp/file"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/tmp" & Character'Val (10), "dirname output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname status");
   end Test_Dirname;

   procedure Test_Dirname_Edge_Cases (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("dirname", One_Arg (""));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "." & LF, "dirname command empty");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname empty status");

      Context.Initialize ("dirname", One_Arg ("///"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/" & LF, "dirname command root");

      Context.Initialize ("dirname", One_Arg ("a//b"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "dirname repeated separator");

      Context.Initialize ("dirname", One_Arg ("/tmp/file"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/tmp" & LF, "dirname absolute path");

      Context.Initialize ("dirname", One_Arg ("a/b/"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "dirname trailing slash");

      Context.Initialize ("dirname", One_Arg ("file"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "." & LF, "dirname no slash");

      Context.Initialize ("dirname", One_Arg ("//tmp"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/" & LF, "dirname two leading slash");

      Context.Initialize ("dirname", One_Arg ("//a/b/"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/a" & LF, "dirname nested two leading slash");

      Context.Initialize ("dirname", One_Arg ("a\b"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "." & LF, "dirname command backslash");
   end Test_Dirname_Edge_Cases;

   procedure Test_Simple_Output_Failures (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("basename", One_Arg ("abc"));
      Test_Contexts.Set_Output_Failure_After (Context, 1);
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a", "basename partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "basename output status");

      Context.Initialize ("dirname", One_Arg ("a/b"));
      Test_Contexts.Set_Output_Failure_After (Context, 1);
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a", "dirname partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "dirname output status");

      Context.Initialize ("echo", Two_Args ("ab", "cd"));
      Test_Contexts.Set_Output_Failure_After (Context, 2);
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "echo partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "echo output status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, "/physical");
      Test_Contexts.Set_Output_Failure_After (Context, 3);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/ph", "pwd partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "pwd output status");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "simple output failure diagnostic");
   end Test_Simple_Output_Failures;

   procedure Test_Echo (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("echo", Three_Args ("", "-n", "x"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = " -n x" & Character'Val (10), "echo output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo status");
   end Test_Echo;

   procedure Test_Echo_Data_Edge_Cases (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("echo", Three_Args ("--", "a\b", "-n"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-- a\b -n" & LF,
         "echo treats -- backslash and -n as data");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo data edge status");

      Context.Initialize ("echo", Three_Args ("--help", "", "value"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "--help  value" & LF,
         "echo non-sole help preserves empty operand");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo non-sole help status");
   end Test_Echo_Data_Edge_Cases;

   procedure Test_Echo_Extensions_Are_Sole_Argument (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("echo", Two_Args ("--help", "value"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "--help value" & Character'Val (10),
         "echo treats non-sole --help as data");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo data status");

      Context.Initialize ("echo", One_Arg ("--version"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "echo (posix-tools) " & Posix_Tools.Version.Version_String & Character'Val (10),
         "echo version output");

      Context.Initialize ("echo", Two_Args ("--posix-tools-identify", "value"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "--posix-tools-identify value" & Character'Val (10),
         "echo treats non-sole identity as data");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo identity data status");
   end Test_Echo_Extensions_Are_Sole_Argument;

   procedure Test_End_Of_Options (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-end-of-options.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("basename", Two_Args ("--", "--help"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "--help" & LF, "basename -- operand output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename -- operand status");

      Context.Initialize ("dirname", Two_Args ("--", "a/b"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "dirname -- operand output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname -- operand status");

      Write_File (Path, "data");
      Context.Initialize ("cat", Two_Args ("--", Path));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "data", "cat skips end-of-options marker");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat -- file status");

      Context.Initialize ("pwd", One_Arg ("--"));
      Test_Contexts.Set_Physical_Current_Directory (Context, "/physical");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/physical" & LF, "pwd -- output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -- status");

      Context.Initialize ("pwd", Two_Args ("--", "extra"));
      Test_Contexts.Set_Physical_Current_Directory (Context, "/physical");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "pwd -- extra status");

      Write_File (Path, "a" & LF & "b" & LF);
      Context.Initialize ("head", Two_Args ("--", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "head skips leading --");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head leading -- status");

      Context.Initialize ("head", Four_Args ("-n", "1", "--", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "head skips -- after count");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head -- status");

      Context.Initialize ("tail", Two_Args ("--", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "tail skips leading --");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail leading -- status");

      Context.Initialize ("tail", Four_Args ("-n", "1", "--", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF, "tail skips -- after count");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -- status");

      Context.Initialize ("wc", Two_Args ("--", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "2 2 4 " & Path & LF, "wc skips leading --");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc leading -- status");

      Context.Initialize ("wc", Three_Args ("-c", "--", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "4 " & Path & LF, "wc skips -- after option");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -- status");
   end Test_End_Of_Options;

   procedure Test_False (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("false", One_Arg ("ignored"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "false output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "false status");
   end Test_False;

   procedure Test_False_Extension_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("false", One_Arg ("--version"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "false (posix-tools) " & Posix_Tools.Version.Version_String & LF,
         "false sole version");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "false version status");

      Context.Initialize ("false", Two_Args ("--version", "ignored"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "false non-sole version ignored");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "false non-sole version status");

      Context.Initialize ("false", Two_Args ("--posix-tools-identify", "ignored"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "false non-sole identity ignored");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "false non-sole identity status");
   end Test_False_Extension_Edges;

   procedure Test_Head_Counts (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-head-counts.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Path, "a" & LF & "b" & LF & "c");

      Context.Initialize ("head", Two_Args ("-n2", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "head -n2 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head -n2 status");

      Context.Initialize ("head", Three_Args ("-n", "0", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "head zero output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head zero status");

      Context.Initialize ("head", Three_Args ("-n", "9", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & LF & "b" & LF & "c",
         "head preserves final partial line");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head large count status");

      Context.Initialize ("head", Five_Args ("-n", "1", "-n", "2", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & LF & "b" & LF,
         "head repeated -n uses last count");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head repeated -n status");
   end Test_Head_Counts;

   procedure Test_Head_Default_Limits (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Short   : constant String := Fixture_Path ("reg-head-default-short.txt");
      Long    : constant String := Fixture_Path ("reg-head-default-long.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Short, "1" & LF & "2" & LF & "3" & LF);
      Context.Initialize ("head", One_Arg (Short));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1" & LF & "2" & LF & "3" & LF,
         "head short default output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head short default status");

      Write_File
        (Long,
         "1" & LF & "2" & LF & "3" & LF & "4" & LF & "5" & LF & "6" & LF
         & "7" & LF & "8" & LF & "9" & LF & "10" & LF & "11" & LF & "12" & LF);
      Context.Initialize ("head", One_Arg (Long));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "1" & LF & "2" & LF & "3" & LF & "4" & LF & "5" & LF & "6" & LF
           & "7" & LF & "8" & LF & "9" & LF & "10" & LF,
         "head long default output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head long default status");
   end Test_Head_Default_Limits;

   procedure Test_Head_Invalid_Count (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("head", One_Arg ("-nabc"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "head invalid count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "head: invalid line count '-nabc'" & Character'Val (10),
         "head invalid count diagnostic");

      Context.Initialize ("head", Two_Args ("-n", "-1"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head negative count status");

      Context.Initialize ("head", Two_Args ("-n", "+1"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head leading plus count status");

      Context.Initialize ("head", Two_Args ("-n", "9223372036854775808"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head overflow count status");

      Context.Initialize ("head", One_Arg ("-n"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head missing count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "head: missing option argument '-n'" & Character'Val (10),
         "head missing count diagnostic");
   end Test_Head_Invalid_Count;

   procedure Test_Head_Multiple_File_Headers (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      First   : constant String := Fixture_Path ("reg-head-header-first.txt");
      Second  : constant String := Fixture_Path ("reg-head-header-second.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (First, "a" & LF & "b" & LF);
      Write_File (Second, "c" & LF & "d" & LF);

      Context.Initialize ("head", Four_Args ("-n", "1", First, Second));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "==> " & First & " <==" & LF
           & "a" & LF
           & LF
           & "==> " & Second & " <==" & LF
           & "c" & LF,
         "head multiple file headers");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head header status");
   end Test_Head_Multiple_File_Headers;

   procedure Test_Head_Standard_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("head", Three_Args ("-n", "2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "head stdin output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head stdin status");

      Context.Initialize ("head", Three_Args ("-n", "1", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "head stdin avoids extra read");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "head stdin avoids extra read diagnostic");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head stdin avoids extra read status");

      Context.Initialize ("head", Four_Args ("-n", "1", "-", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "==> - <==" & LF
           & "a" & LF
           & LF
           & "==> - <==" & LF,
         "head repeated stdin is not rewound");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head repeated stdin status");

      Context.Initialize ("head", Three_Args ("-n", "1", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "head stdin read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "head: 'standard input': cannot read file" & LF,
         "head stdin read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "head stdin read failure status");
   end Test_Head_Standard_Input;

   procedure Test_Head_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("head", Three_Args ("-n", "3", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Test_Contexts.Set_Output_Failure_After (Context, 2);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "head stops after failed write");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "head output failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "head output failure status");
   end Test_Head_Output_Failure;

   procedure Test_Help_And_Version (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("cat", One_Arg ("--help"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: cat [OPTION]... [OPERAND]..." & LF
           & "Ada implementation in the posix-tools package." & LF
           & "Options:" & LF
           & "  --help     display this help and exit" & LF
           & "  --version  display version information and exit" & LF,
         "cat help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat help status");

      Context.Initialize ("cat", One_Arg ("--version"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "cat (posix-tools) " & Posix_Tools.Version.Version_String & LF,
         "cat version output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat version status");
   end Test_Help_And_Version;

   procedure Test_Help_Locales (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      declare
         Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "Danish help status");
         AUnit.Assertions.Assert (Contains (Text, "Brug: cat "), "Danish help usage heading");
         AUnit.Assertions.Assert (Contains (Text, "Valgmuligheder:"), "Danish help options heading");
         AUnit.Assertions.Assert (Contains (Text, "--help"), "Danish help preserves option spelling");
         AUnit.Assertions.Assert (not Contains (Text, "posix_tools."), "Danish help no message-key leak");
      end;

      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Locale (Context, "zz-ZZ");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      declare
         Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Contains (Text, "Usage: cat "), "unknown locale fallback usage");
         AUnit.Assertions.Assert (not Contains (Text, "posix_tools."), "unknown locale no message-key leak");
      end;
   end Test_Help_Locales;

   procedure Test_Diagnostic_Locales (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
      Missing : constant String := Fixture_Path ("missing-da-file.txt");
      Invalid : constant String := Fixture_Path ("invalid-da-utf8.bin");
   begin
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "Danish diagnostic status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "dirname: ekstra operand second" & LF,
         "Danish extra operand diagnostic");
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "Danish diagnostic stdout");

      Context.Initialize ("head", One_Arg ("-n"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "Danish missing option argument status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "head: mangler argument til valgmulighed -n" & LF,
         "Danish missing option argument diagnostic");

      Context.Initialize ("wc", One_Arg ("-z"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "Danish unknown option status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: ukendt valgmulighed -z" & LF,
         "Danish unknown option diagnostic");

      Context.Initialize ("head", One_Arg ("-nabc"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "Danish invalid line count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "head: ugyldigt linjeantal -nabc" & LF,
         "Danish invalid line count diagnostic");

      Context.Initialize ("cat", One_Arg (Missing));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "Danish read failure status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "cat: '" & Missing & "': kan ikke læse fil" & LF,
         "Danish read failure diagnostic");

      Write_File (Invalid, "A" & Character'Val (16#C3#));
      Context.Initialize ("wc", Two_Args ("-m", Invalid));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "Danish invalid UTF-8 status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Invalid & "': ugyldig UTF-8" & LF,
         "Danish invalid UTF-8 diagnostic");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Physical_Current_Directory (Context, "__raise_current_directory__");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "Danish pwd failure status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "pwd: kan ikke bestemme aktuel mappe" & LF,
         "Danish pwd failure diagnostic");

      Context.Initialize ("tail", Two_Args ("-c", "2147483648"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "Danish count too large status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: antal er for stort" & LF,
         "Danish count too large diagnostic");
   end Test_Diagnostic_Locales;

   procedure Test_Presentation_Styling (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      ESC     : constant Character := Character'Val (27);
   begin
      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Never);
      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (not Contains (Test_Contexts.Output (Context), "" & ESC), "unstyled help has no ANSI");
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "Usage: cat "), "unstyled semantic help");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Always);
      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "" & ESC & "["), "styled help has ANSI");
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "Usage"), "styled help keeps usage text");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "--help"),
         "styled help keeps option spelling");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Automatic);
   end Test_Presentation_Styling;

   procedure Test_Identity (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;

      function Expected (Command : String) return String is
      begin
         return
           "schema=1" & Character'Val (10)
           & "project=posix-tools" & Character'Val (10)
           & "command=" & Command & Character'Val (10)
           & "version=" & Posix_Tools.Version.Version_String & Character'Val (10);
      end Expected;
   begin
      Context.Initialize ("basename", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("basename"), "basename identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename identity status");

      Context.Initialize ("cat", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("cat"), "cat identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat identity status");

      Context.Initialize ("dirname", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("dirname"), "dirname identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname identity status");

      Context.Initialize ("echo", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("echo"), "echo identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo identity status");

      Context.Initialize ("false", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("false"), "false identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "false identity status");

      Context.Initialize ("head", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("head"), "head identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head identity status");

      Context.Initialize ("pwd", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("pwd"), "pwd identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd identity status");

      Context.Initialize ("tail", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("tail"), "tail identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail identity status");

      Context.Initialize ("true", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("true"), "true identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true identity status");

      Context.Initialize ("wc", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("wc"), "wc identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc identity status");
   end Test_Identity;

   procedure Test_Pwd_Context_Fallbacks (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      Physical : constant String := "/physical/fallback";
      Logical  : constant String := "/logical/default";
      LF       : constant Character := Character'Val (10);
   begin
      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", Logical);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Logical & LF, "pwd default logical output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd default logical status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", Logical);
      Test_Contexts.Set_Logical_Pwd_Matches_Current_Directory (Context, False);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd stale PWD fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd stale PWD status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd empty PWD fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd empty PWD status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "relative/path");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd relative PWD fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd relative PWD status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/./test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd dot component fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd dot component status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/../test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd dot-dot component fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd dot-dot component status");

      Context.Initialize ("pwd", Two_Args ("-P", "-L"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", Logical);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Logical & LF, "pwd -P -L last option output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -P -L status");
   end Test_Pwd_Context_Fallbacks;

   procedure Test_Pwd_Options (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      Physical : constant String := "/physical/test";
   begin
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");

      Context.Initialize ("pwd", One_Arg ("-L"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "/logical/test" & Character'Val (10),
         "pwd -L output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -L status");

      Context.Initialize ("pwd", One_Arg ("-P"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & Character'Val (10),
         "pwd -P output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -P status");

      Context.Initialize ("pwd", Two_Args ("-L", "-P"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & Character'Val (10),
         "pwd last option wins");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd precedence status");

      Context.Initialize ("pwd", One_Arg ("operand"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "pwd operand status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "pwd: invalid operand 'operand'" & Character'Val (10),
         "pwd operand diagnostic");
   end Test_Pwd_Options;

   procedure Test_Root_List (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      Expected : constant String :=
        "basename" & Character'Val (10)
        & "cat" & Character'Val (10)
        & "dirname" & Character'Val (10)
        & "echo" & Character'Val (10)
        & "false" & Character'Val (10)
        & "head" & Character'Val (10)
        & "pwd" & Character'Val (10)
        & "tail" & Character'Val (10)
        & "true" & Character'Val (10)
        & "wc" & Character'Val (10);
   begin
      Context.Initialize ("posix-tools", One_Arg ("list"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected, "root list output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root list status");
   end Test_Root_List;

   procedure Test_Root_Usage_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("posix-tools", Two_Args ("list", "extra"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "root list extra status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: extra operand 'extra'" & LF,
         "root list extra diagnostic");

      Context.Initialize ("posix-tools", Three_Args ("help", "cat", "extra"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "root help extra status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: extra operand 'extra'" & LF,
         "root help extra diagnostic");

      Context.Initialize ("posix-tools", Two_Args ("help", "missing"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "root help unknown status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: unknown command 'missing'" & LF,
         "root help unknown diagnostic");
   end Test_Root_Usage_Edges;

   procedure Test_Root_Paths (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("paths"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      declare
         Output_Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root paths status");
         AUnit.Assertions.Assert (Contains (Output_Text, "basename: "), "root paths basename line");
         AUnit.Assertions.Assert (Contains (Output_Text, "cat: "), "root paths cat line");
         AUnit.Assertions.Assert (Contains (Output_Text, "dirname: "), "root paths dirname line");
         AUnit.Assertions.Assert (Contains (Output_Text, "echo: "), "root paths echo line");
         AUnit.Assertions.Assert (Contains (Output_Text, "false: "), "root paths false line");
         AUnit.Assertions.Assert (Contains (Output_Text, "head: "), "root paths head line");
         AUnit.Assertions.Assert (Contains (Output_Text, "pwd: "), "root paths pwd line");
         AUnit.Assertions.Assert (Contains (Output_Text, "tail: "), "root paths tail line");
         AUnit.Assertions.Assert (Contains (Output_Text, "true: "), "root paths true line");
         AUnit.Assertions.Assert (Contains (Output_Text, "wc: "), "root paths wc line");
      end;
   end Test_Root_Paths;

   procedure Test_Root_Verify (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("verify"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      declare
         Output_Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root verify status");
         AUnit.Assertions.Assert (Contains (Output_Text, "basename: "), "root verify basename line");
         AUnit.Assertions.Assert (Contains (Output_Text, "cat: "), "root verify cat line");
         AUnit.Assertions.Assert (Contains (Output_Text, "dirname: "), "root verify dirname line");
         AUnit.Assertions.Assert (Contains (Output_Text, "echo: "), "root verify echo line");
         AUnit.Assertions.Assert (Contains (Output_Text, "false: "), "root verify false line");
         AUnit.Assertions.Assert (Contains (Output_Text, "head: "), "root verify head line");
         AUnit.Assertions.Assert (Contains (Output_Text, "pwd: "), "root verify pwd line");
         AUnit.Assertions.Assert (Contains (Output_Text, "tail: "), "root verify tail line");
         AUnit.Assertions.Assert (Contains (Output_Text, "true: "), "root verify true line");
         AUnit.Assertions.Assert (Contains (Output_Text, "wc: "), "root verify wc line");
      end;
   end Test_Root_Verify;

   procedure Test_Root_Command_Help_Uses_Command_Metadata (T : in out Fixture) is
      pragma Unreferenced (T);
      Cat_Context  : Test_Contexts.Capturing_Context;
      Root_Context : Test_Contexts.Capturing_Context;
      Cat_Result   : Posix_Tools.Commands.Results.Result;
      Root_Result  : Posix_Tools.Commands.Results.Result;
   begin
      Cat_Context.Initialize ("cat", One_Arg ("--help"));
      Posix_Tools.Commands.Cat.Run (Cat_Context, Cat_Result);

      Root_Context.Initialize ("posix-tools", Two_Args ("help", "cat"));
      Posix_Tools.Commands.Root.Run (Root_Context, Root_Result);

      AUnit.Assertions.Assert
        (Cat_Result.Status = Posix_Tools.Exit_Status.Success,
         "cat direct help status");
      AUnit.Assertions.Assert
        (Root_Result.Status = Posix_Tools.Exit_Status.Success,
         "root command help status");
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Root_Context) = Test_Contexts.Output (Cat_Context),
         "root command help must reuse command metadata");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Root_Context) = "",
         "root command help stderr");
   end Test_Root_Command_Help_Uses_Command_Metadata;

   procedure Test_Root_Version_And_Help (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("version"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "posix-tools " & Posix_Tools.Version.Version_String & Character'Val (10),
         "root version output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root version status");

      Context.Initialize ("posix-tools", One_Arg ("--version"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "posix-tools " & Posix_Tools.Version.Version_String & Character'Val (10),
         "root --version output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root --version status");

      Context.Initialize ("posix-tools", One_Arg ("--help"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: posix-tools [OPTION]... [OPERAND]..." & Character'Val (10)
           & "Ada implementation in the posix-tools package." & Character'Val (10)
           & "Options:" & Character'Val (10)
           & "  --help     display this help and exit" & Character'Val (10)
           & "  --version  display version information and exit" & Character'Val (10),
         "root --help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root --help status");

      Context.Initialize ("posix-tools", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "schema=1" & Character'Val (10)
           & "project=posix-tools" & Character'Val (10)
           & "command=posix-tools" & Character'Val (10)
           & "version=" & Posix_Tools.Version.Version_String & Character'Val (10),
         "root identity output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root identity status");

      Context.Initialize ("posix-tools", No_Args);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: posix-tools <command> [operand]" & Character'Val (10)
           & "Commands: help, version, list, paths, verify" & Character'Val (10),
         "root default help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root default help status");
   end Test_Root_Version_And_Help;

   procedure Test_Root_Localized_Help (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Brug: posix-tools <command> [operand]" & LF
           & "Kommandoer: help, version, list, paths, verify" & LF,
         "root localized help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root localized help status");

      Context.Initialize ("posix-tools", One_Arg ("bogus"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "root localized unknown subcommand status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: ukendt underkommando bogus" & LF,
         "root localized unknown subcommand diagnostic");

      Context.Initialize ("posix-tools", Two_Args ("help", "bogus"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "root localized unknown help topic status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: ukendt kommando bogus" & LF,
         "root localized unknown help topic diagnostic");
   end Test_Root_Localized_Help;

   procedure Test_Root_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Output_Failure_After (Context, 5);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "Usage", "root partial output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "root output failure status");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "root output failure diagnostic");
   end Test_Root_Output_Failure;

   procedure Test_Tail_Byte_Mode_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-tail-byte-mode.bin");
      Spill_Path : constant String := Fixture_Path ("reg-tail-byte-spill.bin");
   begin
      Write_File (Path, "abcdef");

      Context.Initialize ("tail", Three_Args ("-c", "0", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "tail -c 0 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c 0 status");

      Context.Initialize ("tail", Three_Args ("-c", "3", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "tail -c 3 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c 3 status");

      Context.Initialize ("tail", Three_Args ("-c", "20", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "tail -c larger than input output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail -c larger than input status");

      Context.Initialize ("tail", Three_Args ("-c", "+4", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "tail -c +4 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c +4 status");

      Context.Initialize ("tail", Three_Args ("-c", "6", Spill_Path));
      Test_Contexts.Set_Tail_Resource_Limits (Context, 3, 64);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "fghij" & Character'Val (10),
         "tail -c spill output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c spill status");

      Context.Initialize ("tail", Three_Args ("-c", "6", Spill_Path));
      Test_Contexts.Set_Tail_Resource_Limits (Context, 3, 4);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "tail max spill failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: count too large" & Character'Val (10),
         "tail max spill diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tail max spill failure status");
   end Test_Tail_Byte_Mode_Edges;

   procedure Test_Tail_Compact_Counts (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-tail-compact.bin");
   begin
      Write_File (Path, "abcdef");

      Context.Initialize ("tail", Two_Args ("-c2", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ef", "tail -c2 compact output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c2 status");

      Context.Initialize ("tail", Two_Args ("-c+4", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "tail -c+4 compact output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c+4 status");

      Context.Initialize ("tail", Five_Args ("-n", "1", "-c", "2", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ef", "tail later -c overrides earlier -n");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail later -c status");

      Context.Initialize ("tail", Five_Args ("-c", "2", "-n", "1", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "tail later -n overrides earlier -c");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail later -n status");
   end Test_Tail_Compact_Counts;

   procedure Test_Tail_Plus_Origin (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-tail-plus.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Path, "a" & LF & "b" & LF & "c" & LF);

      Context.Initialize ("tail", Three_Args ("-n", "+2", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & LF & "c" & LF,
         "tail -n +2 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -n +2 status");

      Context.Initialize ("tail", Two_Args ("-n+2", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF & "c" & LF, "tail -n+2 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -n+2 status");
   end Test_Tail_Plus_Origin;

   procedure Test_Tail_Invalid_Count (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("tail", One_Arg ("-cabc"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "tail invalid count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: invalid count '-cabc'" & Character'Val (10),
         "tail invalid count diagnostic");

      Context.Initialize ("tail", Two_Args ("-n", "-1"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail negative count status");

      Context.Initialize ("tail", Two_Args ("-n", "+"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail lone plus count status");

      Context.Initialize ("tail", Two_Args ("-c", "9223372036854775808"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail overflow count status");

      Context.Initialize ("tail", One_Arg ("-n"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail missing -n count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: missing option argument '-n'" & Character'Val (10),
         "tail missing -n diagnostic");

      Context.Initialize ("tail", One_Arg ("-c"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail missing -c count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: missing option argument '-c'" & Character'Val (10),
         "tail missing -c diagnostic");
   end Test_Tail_Invalid_Count;

   procedure Test_Tail_Line_Mode_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-tail-line-mode.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Path, "a" & LF & "b" & LF & "c");

      Context.Initialize ("tail", One_Arg (Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & LF & "b" & LF & "c",
         "tail default ten lines from end output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail default ten lines from end status");

      Context.Initialize ("tail", Three_Args ("-n", "0", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "tail -n 0 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -n 0 status");

      Context.Initialize ("tail", Three_Args ("-n", "20", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & LF & "b" & LF & "c",
         "tail line count larger than input output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail line count larger than input status");

      Context.Initialize ("tail", Three_Args ("-n", "1", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "c", "tail final partial line output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail final partial status");

      Context.Initialize ("tail", Three_Args ("-n", "2", Path));
      Test_Contexts.Set_Tail_Resource_Limits (Context, 2, 64);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & LF & "c",
         "tail line spill final partial output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail line spill final partial status");

      Context.Initialize ("tail", Three_Args ("-n", "2", Path));
      Test_Contexts.Set_Tail_Resource_Limits (Context, 2, 4);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "tail line max spill failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: count too large" & LF,
         "tail line max spill diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tail line max spill failure status");
   end Test_Tail_Line_Mode_Edges;

   procedure Test_Tail_Multiple_File_Headers (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      First   : constant String := Fixture_Path ("reg-tail-head-first.txt");
      Second  : constant String := Fixture_Path ("reg-tail-head-second.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (First, "a" & LF & "b" & LF);
      Write_File (Second, "c" & LF & "d" & LF);

      Context.Initialize ("tail", Four_Args ("-n", "1", First, Second));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "==> " & First & " <==" & LF
           & "b" & LF
           & LF
           & "==> " & Second & " <==" & LF
           & "d" & LF,
         "tail multiple file headers");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail header status");
   end Test_Tail_Multiple_File_Headers;

   procedure Test_Tail_Standard_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("tail", Three_Args ("-n", "2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF & "c" & LF, "tail stdin output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail stdin status");

      Context.Initialize ("tail", Three_Args ("-n", "2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Test_Contexts.Set_Tail_Resource_Limits (Context, 2, 64);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & LF & "c" & LF,
         "tail stdin line spill output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail stdin line spill status");

      Context.Initialize ("tail", Four_Args ("-n", "1", "-", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "==> - <==" & LF
           & "b" & LF
           & LF
           & "==> - <==" & LF,
         "tail repeated stdin is not rewound");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail repeated stdin status");

      Context.Initialize ("tail", Three_Args ("-n", "1", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "tail stdin read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "tail: 'standard input': cannot read file" & LF,
         "tail stdin read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tail stdin read failure status");
   end Test_Tail_Standard_Input;

   procedure Test_Tail_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("tail", Three_Args ("-n", "2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Test_Contexts.Set_Output_Failure_After (Context, 2);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF, "tail stops after failed write");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "tail output failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tail output failure status");
   end Test_Tail_Output_Failure;

   procedure Test_Usage_Errors (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "dirname extra status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "dirname: extra operand 'second'" & Character'Val (10),
         "dirname extra diagnostic");

      Context.Initialize ("posix-tools", One_Arg ("unknown"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "root unknown status");
   end Test_Usage_Errors;

   procedure Test_True (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("true", One_Arg ("ignored"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "true output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true status");
   end Test_True;

   procedure Test_True_Extension_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("true", One_Arg ("--help"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: true [OPTION]... [OPERAND]..." & LF
           & "Ada implementation in the posix-tools package." & LF
           & "Options:" & LF
           & "  --help     display this help and exit" & LF
           & "  --version  display version information and exit" & LF,
         "true sole help");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true help status");

      Context.Initialize ("true", Two_Args ("--help", "ignored"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "true non-sole help ignored");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true non-sole help status");

      Context.Initialize ("true", Two_Args ("--posix-tools-identify", "ignored"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "true non-sole identity ignored");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true non-sole identity status");
   end Test_True_Extension_Edges;

   procedure Test_Wc_Text_Counts (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-wc-utf8.txt");
   begin
      Write_File (Path, "A " & Character'Val (16#C3#) & Character'Val (16#A6#) & Character'Val (10));

      Context.Initialize ("wc", Two_Args ("-m", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "4 " & Path & Character'Val (10), "wc -m output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -m status");
   end Test_Wc_Text_Counts;

   procedure Test_Wc_Default_And_Mixed_Text (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-wc-default.txt");
      Invalid : constant String := Fixture_Path ("reg-wc-mixed-invalid.bin");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Path, "a b" & LF & "c");

      Context.Initialize ("wc", One_Arg (Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1 3 5 " & Path & LF,
         "wc default field order");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc default status");

      Write_File (Invalid, "A" & Character'Val (16#C3#));
      Context.Initialize ("wc", One_Arg (Invalid));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc default invalid suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Invalid & "': invalid UTF-8" & LF,
         "wc default invalid diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc default invalid status");

      Context.Initialize ("wc", Two_Args ("-cm", Invalid));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc mixed invalid suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Invalid & "': invalid UTF-8" & LF,
         "wc mixed invalid diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc mixed invalid status");

      Context.Initialize ("wc", One_Arg ("-L"));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc -L unsupported output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: unknown option '-L'" & LF,
         "wc -L unsupported diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "wc -L unsupported status");
   end Test_Wc_Default_And_Mixed_Text;

   procedure Test_Wc_Text_Invalid_UTF_8 (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-wc-invalid.bin");
   begin
      Write_File (Path, "A" & Character'Val (16#C3#));

      Context.Initialize ("wc", Two_Args ("-c", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "2 " & Path & Character'Val (10), "wc -c raw output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -c raw status");

      Context.Initialize ("wc", Two_Args ("-l", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "0 " & Path & Character'Val (10), "wc -l raw output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -l raw status");

      Context.Initialize ("wc", Two_Args ("-cl", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0 2 " & Path & Character'Val (10),
         "wc -cl raw output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -cl raw status");

      Context.Initialize ("wc", Two_Args ("-m", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc -m invalid suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Path & "': invalid UTF-8" & Character'Val (10),
         "wc -m invalid diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc -m invalid status");
   end Test_Wc_Text_Invalid_UTF_8;

   procedure Test_Wc_Text_Malformed_UTF_8 (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Overlong : constant String := Fixture_Path ("reg-wc-overlong.bin");
      Bad_Continuation : constant String := Fixture_Path ("reg-wc-bad-continuation.bin");
      Surrogate : constant String := Fixture_Path ("reg-wc-surrogate.bin");
      Out_Of_Range : constant String := Fixture_Path ("reg-wc-out-of-range.bin");
   begin
      Write_File (Overlong, Character'Val (16#C0#) & Character'Val (16#AF#));
      Context.Initialize ("wc", Two_Args ("-m", Overlong));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc overlong suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Overlong & "': invalid UTF-8" & Character'Val (10),
         "wc overlong diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc overlong status");

      Write_File (Bad_Continuation, Character'Val (16#E2#) & "A");
      Context.Initialize ("wc", Two_Args ("-w", Bad_Continuation));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc bad continuation suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "wc: '" & Bad_Continuation & "': invalid UTF-8" & Character'Val (10),
         "wc bad continuation diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc bad continuation status");

      Write_File
        (Surrogate,
         Character'Val (16#ED#) & Character'Val (16#A0#) & Character'Val (16#80#));
      Context.Initialize ("wc", Two_Args ("-m", Surrogate));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc surrogate suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Surrogate & "': invalid UTF-8" & Character'Val (10),
         "wc surrogate diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc surrogate status");

      Write_File
        (Out_Of_Range,
         Character'Val (16#F4#) & Character'Val (16#90#)
         & Character'Val (16#80#) & Character'Val (16#80#));
      Context.Initialize ("wc", Two_Args ("-m", Out_Of_Range));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc out-of-range suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "wc: '" & Out_Of_Range & "': invalid UTF-8" & Character'Val (10),
         "wc out-of-range diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc out-of-range status");
   end Test_Wc_Text_Malformed_UTF_8;

   procedure Test_Wc_Multiple_Files (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      First   : constant String := Fixture_Path ("reg-wc-first.txt");
      Second  : constant String := Fixture_Path ("reg-wc-second.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (First, "a b" & LF);
      Write_File (Second, "c" & LF & "d" & LF);

      Context.Initialize ("wc", Three_Args ("-lw", First, Second));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "1 2 " & First & LF
           & "2 2 " & Second & LF
           & "3 4 total" & LF,
         "wc multiple file totals");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc multiple status");

      Context.Initialize ("wc", Four_Args ("-l", First, Fixture_Path ("reg-wc-missing.txt"), Second));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "1 " & First & LF
           & "2 " & Second & LF
           & "3 total" & LF,
         "wc totals successful files after failed file");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "reg-wc-missing.txt"),
         "wc missing file diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc failed file aggregate status");
   end Test_Wc_Multiple_Files;

   procedure Test_Wc_Standard_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("wc", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a b" & LF);
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "1 2 4" & LF, "wc stdin default output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc stdin default status");

      Context.Initialize ("wc", Three_Args ("-c", "-", "-"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "3 -" & LF
           & "0 -" & LF
           & "3 total" & LF,
         "wc repeated stdin is not rewound");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc repeated stdin status");

      Context.Initialize ("wc", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a b" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc stdin read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "wc: 'standard input': cannot read file" & LF,
         "wc stdin read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc stdin read failure status");
   end Test_Wc_Standard_Input;

   procedure Test_Wc_Byte_Count_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;
      type Length_Array is array (Positive range <>) of Natural;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("property-wc-c.bin");
      LF      : constant Character := Character'Val (10);
      Seed    : Word_32 := 16#5EED_C0DE#;
      Lengths : constant Length_Array := [0, 1, 2, 7, 31, 64, 127, 256, 513];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Next_Byte return Character is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Character'Val (Natural ((Seed / 16#0100_0000#) mod 256));
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            Result (I) := Next_Byte;
         end loop;

         return Result;
      end Generated;
   begin
      for Length of Lengths loop
         declare
            Data : constant String := Generated (Length);
         begin
            Write_File (Path, Data);
            Context.Initialize ("wc", Two_Args ("-c", Path));
            Posix_Tools.Commands.Wc.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Decimal_Image (Length) & " " & Path & LF,
               "wc -c property seed 0x5EEDC0DE length" & Natural'Image (Length));
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "wc -c property status seed 0x5EEDC0DE length" & Natural'Image (Length));
         end;
      end loop;

      Ada.Directories.Delete_File (Path);
   end Test_Wc_Byte_Count_Property;

   procedure Test_Wc_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("wc", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Output_Failure_After (Context, 1);
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "0", "wc partial output before failure");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "wc output failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc output failure status");
   end Test_Wc_Output_Failure;
end Command_Tests;
