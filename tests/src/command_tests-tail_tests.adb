with Ada.Directories;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Tail;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Command_Tests.Tail_Tests is
   use type Posix_Tools.Exit_Status.Code;

   function One_Arg (A : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.One_Arg;
   function Two_Args (A, B : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Two_Args;
   function Three_Args (A, B, C : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Three_Args;
   function Four_Args (A, B, C, D : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Four_Args;
   function Five_Args (A, B, C, D, E : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Five_Args;

   function Fixture_Path (Name : String) return String
     renames Test_Support.Work_Path;
   procedure Write_File (Path, Data : String)
     renames Test_Support.Write_File;

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

      Write_File (Spill_Path, "abcdefghij" & Character'Val (10));
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

   procedure Test_Tail_Follow_Live (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-tail-follow-option.txt");
      Reopen  : constant String := Fixture_Path ("reg-tail-follow-reopen.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Path, "a" & LF & "b" & LF);

      Context.Initialize ("tail", Four_Args ("-f", "-n", "1", Path));
      Test_Contexts.Set_Tail_Follow_Poll_Limit (Context, 2);
      Test_Contexts.Set_Tail_Follow_Append (Context, Path, 1, "c" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF & "c" & LF, "tail -f live output");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "tail -f live diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail -f live status");

      Write_File (Path, "a" & LF & "b" & LF);
      Context.Initialize ("tail", Four_Args ("-n", "1", "-f", Path));
      Test_Contexts.Set_Tail_Follow_Poll_Limit (Context, 2);
      Test_Contexts.Set_Tail_Follow_Append (Context, Path, 1, "c" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF & "c" & LF, "tail -f after count live output");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "tail -f after count live diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail -f after count live status");

      Write_File (Reopen, "older" & LF);
      Context.Initialize ("tail", Four_Args ("-F", "-n", "1", Reopen));
      Test_Contexts.Set_Tail_Follow_Poll_Limit (Context, 2);
      Test_Contexts.Set_Tail_Follow_Replace (Context, Reopen, 1, "n" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "older" & LF & "n" & LF, "tail -F reopen output");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "tail -F reopen diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail -F reopen status");

      Write_File (Path, "a" & LF & "b" & LF);
      Context.Initialize ("tail", Four_Args ("--follow", "-n", "1", Path));
      Test_Contexts.Set_Tail_Follow_Poll_Limit (Context, 2);
      Test_Contexts.Set_Tail_Follow_Append (Context, Path, 1, "c" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF & "c" & LF, "tail --follow live output");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "tail --follow live diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail --follow live status");

      Ada.Directories.Delete_File (Path);
      Ada.Directories.Delete_File (Reopen);
   end Test_Tail_Follow_Live;

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

      Context.Initialize ("tail", One_Arg ("-fn5"));
      Test_Contexts.Set_Standard_Input (Context, "a" & Character'Val (10));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tail takes -n grouped behind -f");

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

   end Test_Tail_Invalid_Count;

   procedure Test_Tail_Missing_Count (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("tail", One_Arg ("-n"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail missing -n count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "tail: missing option argument '-n'" & Character'Val (10),
         "tail missing -n diagnostic");

      Context.Initialize ("tail", One_Arg ("-c"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail missing -c count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "tail: missing option argument '-c'" & Character'Val (10),
         "tail missing -c diagnostic");
   end Test_Tail_Missing_Count;

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

   procedure Test_Tail_Byte_Suffix_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;
      type Count_Array is array (Positive range <>) of Natural;
      type Length_Array is array (Positive range <>) of Natural;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("property-tail-c.bin");
      Initial_Seed : constant Word_32 := 16#5441_494C#;
      Seed    : Word_32 := Initial_Seed;
      Counts  : constant Count_Array := [0, 1, 2, 7, 32, 255, 2048];
      Lengths : constant Length_Array := [0, 1, 2, 31, 256, 1025];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Expected_Suffix (Data : String; Count : Natural) return String is
      begin
         if Count = 0 then
            return "";
         elsif Count >= Data'Length then
            return Data;
         else
            return Data (Data'Last - Count + 1 .. Data'Last);
         end if;
      end Expected_Suffix;

      function Next_Byte return Character is
      begin
         Test_Support.Advance (Seed);
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

            for Count of Counts loop
               Context.Initialize ("tail", Three_Args ("-c", Decimal_Image (Count), Path));
               Posix_Tools.Commands.Tail.Run (Context, Result);
               AUnit.Assertions.Assert
                 (Test_Contexts.Output (Context) = Expected_Suffix (Data, Count),
                  "tail -c property " & Test_Support.Seed_Label (Initial_Seed) & " length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
               AUnit.Assertions.Assert
                 (Result.Status = Posix_Tools.Exit_Status.Success,
                  "tail -c property status " & Test_Support.Seed_Label (Initial_Seed) & " length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
            end loop;
         end;
      end loop;

      Ada.Directories.Delete_File (Path);
   end Test_Tail_Byte_Suffix_Property;

   procedure Test_Tail_Standard_Input_Byte_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      type Count_Array is array (Positive range <>) of Natural;
      type Length_Array is array (Positive range <>) of Natural;

      Initial_Seed : constant Word_32 := 16#5441_4953#;
      Seed    : Word_32 := Initial_Seed;
      Counts  : constant Count_Array := [0, 1, 2, 9, 64, 512];
      Lengths : constant Length_Array := [0, 1, 8, 65, 300, 900];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Expected_Suffix (Data : String; Count : Natural) return String is
      begin
         if Count = 0 then
            return "";
         elsif Count >= Data'Length then
            return Data;
         else
            return Data (Data'Last - Count + 1 .. Data'Last);
         end if;
      end Expected_Suffix;

      function Next_Byte return Character is
      begin
         return Test_Support.Next_C_Byte (Seed);
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
            for Count of Counts loop
               declare
                  Context : Test_Contexts.Capturing_Context;
                  Result  : Posix_Tools.Commands.Results.Result;
               begin
                  Context.Initialize ("tail", Two_Args ("-c", Decimal_Image (Count)));
                  Test_Contexts.Set_Standard_Input (Context, Data);
                  Posix_Tools.Commands.Tail.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Test_Contexts.Output (Context) = Expected_Suffix (Data, Count),
                     "tail stdin -c property " & Test_Support.Seed_Label (Initial_Seed) & " length"
                     & Natural'Image (Length) & " count" & Natural'Image (Count));
                  AUnit.Assertions.Assert
                    (Result.Status = Posix_Tools.Exit_Status.Success,
                     "tail stdin -c property status " & Test_Support.Seed_Label (Initial_Seed) & " length"
                     & Natural'Image (Length) & " count" & Natural'Image (Count));
               end;
            end loop;
         end;
      end loop;
   end Test_Tail_Standard_Input_Byte_Property;

   procedure Test_Tail_Line_Suffix_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;
      type Count_Array is array (Positive range <>) of Natural;
      type Length_Array is array (Positive range <>) of Natural;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("property-tail-n.bin");
      LF      : constant Character := Character'Val (10);
      Initial_Seed : constant Word_32 := 16#5441_494E#;
      Seed    : Word_32 := Initial_Seed;
      Counts  : constant Count_Array := [0, 1, 2, 5, 17, 64];
      Lengths : constant Length_Array := [0, 1, 12, 13, 63, 257, 1024];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Line_Count (Data : String) return Natural is
         Result : Natural := 0;
      begin
         for Ch of Data loop
            if Ch = LF then
               Result := Result + 1;
            end if;
         end loop;

         if Data'Length > 0 and then Data (Data'Last) /= LF then
            Result := Result + 1;
         end if;

         return Result;
      end Line_Count;

      function Expected_Line_Suffix (Data : String; Count : Natural) return String is
         Lines_To_Skip : constant Natural := (if Line_Count (Data) > Count then Line_Count (Data) - Count else 0);
         Skipped       : Natural := 0;
      begin
         if Count = 0 or else Data'Length = 0 then
            return "";
         elsif Lines_To_Skip = 0 then
            return Data;
         end if;

         for I in Data'Range loop
            if Data (I) = LF then
               Skipped := Skipped + 1;
               if Skipped = Lines_To_Skip then
                  if I = Data'Last then
                     return "";
                  else
                     return Data (I + 1 .. Data'Last);
                  end if;
               end if;
            end if;
         end loop;

         return Data;
      end Expected_Line_Suffix;

      function Next_Byte return Character is
      begin
         Test_Support.Advance (Seed);
         return Character'Val (Natural ((Seed / 16#0100_0000#) mod 256));
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            if I mod 13 = 0 then
               Result (I) := LF;
            else
               Result (I) := Next_Byte;
            end if;
         end loop;

         return Result;
      end Generated;
   begin
      for Length of Lengths loop
         declare
            Data : constant String := Generated (Length);
         begin
            Write_File (Path, Data);

            for Count of Counts loop
               Context.Initialize ("tail", Three_Args ("-n", Decimal_Image (Count), Path));
               Posix_Tools.Commands.Tail.Run (Context, Result);
               AUnit.Assertions.Assert
                 (Test_Contexts.Output (Context) = Expected_Line_Suffix (Data, Count),
                  "tail -n property " & Test_Support.Seed_Label (Initial_Seed) & " length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
               AUnit.Assertions.Assert
                 (Result.Status = Posix_Tools.Exit_Status.Success,
                  "tail -n property status " & Test_Support.Seed_Label (Initial_Seed) & " length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
            end loop;
         end;
      end loop;

      Ada.Directories.Delete_File (Path);
   end Test_Tail_Line_Suffix_Property;
end Command_Tests.Tail_Tests;
