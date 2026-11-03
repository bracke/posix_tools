with Ada.Directories;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Wc;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Command_Tests.Wc_Tests is
   use type Posix_Tools.Exit_Status.Code;

   function No_Args return Posix_Tools.Arguments.Vector
     renames Test_Support.No_Args;
   function One_Arg (A : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.One_Arg;
   function Two_Args (A, B : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Two_Args;
   function Three_Args (A, B, C : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Three_Args;
   function Four_Args (A, B, C, D : String) return Posix_Tools.Arguments.Vector
     renames Test_Support.Four_Args;

   function Fixture_Path (Name : String) return String
     renames Test_Support.Work_Path;
   function Contains (Text, Pattern : String) return Boolean
     renames Test_Support.Contains;
   procedure Write_File (Path, Data : String)
     renames Test_Support.Write_File;

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
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0 1 2 " & Invalid & LF,
         "wc default counts an invalid byte as part of a word");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "wc default invalid has no diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "wc default invalid status");

      Context.Initialize ("wc", Two_Args ("-cm", Invalid));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "2 2 " & Invalid & LF,
         "wc -cm counts an invalid byte as a character");

      Context.Initialize ("wc", One_Arg ("-mw"));
      Test_Contexts.Set_Locale (Context, "C");
      Test_Contexts.Set_Standard_Input (Context, "a" & Character'Val (16#E9#) & " b" & LF);
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "2 5" & LF,
         "wc counts bytes as characters in the C locale");

      Write_File (Path, "ab" & LF & Character'Val (9) & "c" & LF & "abcd");
      Context.Initialize ("wc", Two_Args ("-L", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "9 " & Path & LF,
         "wc -L maximum line length output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -L status");

      Context.Initialize ("wc", Two_Args ("-lL", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "2 9 " & Path & LF,
         "wc -lL output ordering");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "wc -lL status");
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
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "2 " & Path & Character'Val (10),
         "wc -m counts an incomplete sequence as a character");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "wc -m invalid status");
   end Test_Wc_Text_Invalid_UTF_8;

   procedure Test_Wc_Text_Malformed_UTF_8 (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Overlong : constant String := Fixture_Path ("reg-wc-overlong.bin");
      Bad_Continuation : constant String := Fixture_Path ("reg-wc-bad-continuation.bin");
   begin
      Write_File (Overlong, Character'Val (16#C0#) & Character'Val (16#AF#));
      Context.Initialize ("wc", Two_Args ("-m", Overlong));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "2 " & Overlong & Character'Val (10)
         and then Test_Contexts.Error_Output (Context) = "",
         "wc counts overlong UTF-8 without failing");

      Write_File (Bad_Continuation, Character'Val (16#E2#) & "A");
      Context.Initialize ("wc", Two_Args ("-w", Bad_Continuation));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1 " & Bad_Continuation & Character'Val (10)
         and then Test_Contexts.Error_Output (Context) = "",
         "wc counts bad continuation UTF-8 without failing");

   end Test_Wc_Text_Malformed_UTF_8;

   procedure Test_Wc_Text_Code_Point_Validity (T : in out Fixture) is
      pragma Unreferenced (T);
      Context      : Test_Contexts.Capturing_Context;
      Result       : Posix_Tools.Commands.Results.Result;
      Surrogate    : constant String := Fixture_Path ("reg-wc-surrogate.bin");
      Out_Of_Range : constant String := Fixture_Path ("reg-wc-out-of-range.bin");
   begin
      Write_File
        (Surrogate,
         Character'Val (16#ED#) & Character'Val (16#A0#)
         & Character'Val (16#80#));
      Context.Initialize ("wc", Two_Args ("-m", Surrogate));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "1 " & Surrogate & Character'Val (10)
         and then Test_Contexts.Error_Output (Context) = "",
         "wc counts surrogate UTF-8 without failing");

      Write_File
        (Out_Of_Range,
         Character'Val (16#F4#) & Character'Val (16#90#)
         & Character'Val (16#80#) & Character'Val (16#80#));
      Context.Initialize ("wc", Two_Args ("-m", Out_Of_Range));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "1 " & Out_Of_Range & Character'Val (10)
         and then Test_Contexts.Error_Output (Context) = "",
         "wc counts out-of-range UTF-8 without failing");
   end Test_Wc_Text_Code_Point_Validity;

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
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;
      type Length_Array is array (Positive range <>) of Natural;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("property-wc-c.bin");
      LF      : constant Character := Character'Val (10);
      Initial_Seed : constant Word_32 := 16#5EED_C0DE#;
      Seed    : Word_32 := Initial_Seed;
      Lengths : constant Length_Array := [0, 1, 2, 7, 31, 64, 127, 256, 513];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

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
            Context.Initialize ("wc", Two_Args ("-c", Path));
            Posix_Tools.Commands.Wc.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Decimal_Image (Length) & " " & Path & LF,
               "wc -c property " & Test_Support.Seed_Label (Initial_Seed) & " length" & Natural'Image (Length));
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "wc -c property status " & Test_Support.Seed_Label (Initial_Seed) & " length" & Natural'Image (Length));
         end;
      end loop;

      Ada.Directories.Delete_File (Path);
   end Test_Wc_Byte_Count_Property;

   procedure Test_Wc_Standard_Input_Byte_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      type Length_Array is array (Positive range <>) of Natural;

      LF      : constant Character := Character'Val (10);
      Initial_Seed : constant Word_32 := 16#57C0_0001#;
      Seed    : Word_32 := Initial_Seed;
      Lengths : constant Length_Array := [0, 1, 4, 33, 128, 777];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

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
            Context : Test_Contexts.Capturing_Context;
            Result  : Posix_Tools.Commands.Results.Result;
            Data    : constant String := Generated (Length);
         begin
            Context.Initialize ("wc", One_Arg ("-c"));
            Test_Contexts.Set_Standard_Input (Context, Data);
            Posix_Tools.Commands.Wc.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Decimal_Image (Length) & LF,
               "wc stdin -c property " & Test_Support.Seed_Label (Initial_Seed)
               & " length" & Natural'Image (Length));
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "wc stdin -c property status " & Test_Support.Seed_Label (Initial_Seed)
               & " length" & Natural'Image (Length));
         end;
      end loop;
   end Test_Wc_Standard_Input_Byte_Property;

   procedure Test_Wc_Line_Count_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;
      type Length_Array is array (Positive range <>) of Natural;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("property-wc-l.bin");
      LF      : constant Character := Character'Val (10);
      Initial_Seed : constant Word_32 := 16#1F1E_5EED#;
      Seed    : Word_32 := Initial_Seed;
      Lengths : constant Length_Array := [0, 1, 3, 8, 17, 64, 129, 512, 1_025];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Next_Byte return Character is
      begin
         Test_Support.Advance_C (Seed);
         if Seed mod 11 = 0 then
            return LF;
         end if;

         return Character'Val (Natural ((Seed / 16#0001_0000#) mod 255) + 1);
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

      function LF_Count (Data : String) return Natural is
         Count : Natural := 0;
      begin
         for C of Data loop
            if C = LF then
               Count := Count + 1;
            end if;
         end loop;

         return Count;
      end LF_Count;
   begin
      for Length of Lengths loop
         declare
            Data  : constant String := Generated (Length);
            Lines : constant Natural := LF_Count (Data);
         begin
            Write_File (Path, Data);
            Context.Initialize ("wc", Two_Args ("-l", Path));
            Posix_Tools.Commands.Wc.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Decimal_Image (Lines) & " " & Path & LF,
               "wc -l property " & Test_Support.Seed_Label (Initial_Seed) & " length" & Natural'Image (Length)
               & " lines" & Natural'Image (Lines));
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "wc -l property status " & Test_Support.Seed_Label (Initial_Seed) & " length" & Natural'Image (Length));
         end;
      end loop;

      Ada.Directories.Delete_File (Path);
   end Test_Wc_Line_Count_Property;

   procedure Test_Wc_Standard_Input_Line_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;
      type Length_Array is array (Positive range <>) of Natural;

      LF      : constant Character := Character'Val (10);
      Initial_Seed : constant Word_32 := 16#57C0_000A#;
      Seed    : Word_32 := Initial_Seed;
      Lengths : constant Length_Array := [0, 1, 5, 34, 130, 778];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Next_Byte return Character is
      begin
         Test_Support.Advance_C (Seed);
         if Seed mod 13 = 0 then
            return LF;
         end if;

         return Character'Val (Natural ((Seed / 16#0001_0000#) mod 255) + 1);
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

      function LF_Count (Data : String) return Natural is
         Count : Natural := 0;
      begin
         for C of Data loop
            if C = LF then
               Count := Count + 1;
            end if;
         end loop;

         return Count;
      end LF_Count;
   begin
      for Length of Lengths loop
         declare
            Context : Test_Contexts.Capturing_Context;
            Result  : Posix_Tools.Commands.Results.Result;
            Data    : constant String := Generated (Length);
            Lines   : constant Natural := LF_Count (Data);
         begin
            Context.Initialize ("wc", One_Arg ("-l"));
            Test_Contexts.Set_Standard_Input (Context, Data);
            Posix_Tools.Commands.Wc.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Decimal_Image (Lines) & LF,
               "wc stdin -l property " & Test_Support.Seed_Label (Initial_Seed) & " length" & Natural'Image (Length)
               & " lines" & Natural'Image (Lines));
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "wc stdin -l property status " & Test_Support.Seed_Label (Initial_Seed)
               & " length" & Natural'Image (Length));
         end;
      end loop;
   end Test_Wc_Standard_Input_Line_Property;

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
end Command_Tests.Wc_Tests;
