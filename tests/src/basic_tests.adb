with Ada.Directories;
with Ada.Containers;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Arguments.Parsing;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Numbers;
with Posix_Tools.Paths;
with Posix_Tools.Streams.Counting;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Text.Classification;
with Posix_Tools.Text.Whitespace_Data;
with Posix_Tools.Text.UTF_8;
with Posix_Tools.Version;

package body Basic_Tests is
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   function Args (A, B, C : String := "") return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      if A /= "" then
         Result.Append (A);
      end if;
      if B /= "" then
         Result.Append (B);
      end if;
      if C /= "" then
         Result.Append (C);
      end if;
      return Result;
   end Args;

   procedure Test_Command_Inventory (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Command_Count = 10, "inventory count");
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Executable (1) = "basename", "first command");
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Executable (10) = "wc", "last command");
      AUnit.Assertions.Assert
        (Posix_Tools.Command_Inventory.Manifest_Path (1) = "tools/basename/alire.toml",
         "manifest path");
      AUnit.Assertions.Assert
        (Posix_Tools.Command_Inventory.Project_File_Path (10) = "tools/wc/posix_tools_wc.gpr",
         "project file path");
      AUnit.Assertions.Assert
        (Posix_Tools.Command_Inventory.Documentation_Path (8) = "docs/commands/tail.md",
         "documentation path");
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Has_Help (1), "help flag");
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Has_Version (1), "version flag");
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Has_Identity (1), "identity flag");
      AUnit.Assertions.Assert
        (Posix_Tools.Command_Inventory.Posix_Status (8) = "known_deviation",
         "status value");
      AUnit.Assertions.Assert
        (Posix_Tools.Command_Inventory.Posix_Status (10) = "conforming_with_extensions",
         "wc status value");
   end Test_Command_Inventory;

   procedure Test_Numbers (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Posix_Tools.Numbers.Count;
      use type Posix_Tools.Numbers.Parse_Status;
      Parsed : Posix_Tools.Numbers.Parse_Result;
   begin
      Parsed := Posix_Tools.Numbers.Parse_Nonnegative ("42");
      AUnit.Assertions.Assert
        (Parsed.Status = Posix_Tools.Numbers.Valid and then Parsed.Value = 42,
         "parse valid");
      AUnit.Assertions.Assert
        (Posix_Tools.Numbers.Parse_Nonnegative ("").Status = Posix_Tools.Numbers.Empty,
         "parse empty");
      AUnit.Assertions.Assert
        (Posix_Tools.Numbers.Parse_Nonnegative ("-1").Status =
           Posix_Tools.Numbers.Negative_Not_Permitted,
         "parse negative");
      AUnit.Assertions.Assert
        (Posix_Tools.Numbers.Parse_Nonnegative ("abc").Status =
           Posix_Tools.Numbers.Invalid_Syntax,
         "parse invalid");

      Parsed := Posix_Tools.Numbers.Parse_Nonnegative ("9223372036854775807");
      AUnit.Assertions.Assert
        (Parsed.Status = Posix_Tools.Numbers.Valid
         and then Parsed.Value = Posix_Tools.Numbers.Count'Last,
         "parse maximum count");
      AUnit.Assertions.Assert
        (Posix_Tools.Numbers.Parse_Nonnegative ("9223372036854775808").Status =
           Posix_Tools.Numbers.Overflow,
         "parse overflow");
      AUnit.Assertions.Assert
        (Posix_Tools.Numbers.Parse_Nonnegative ("+1").Status =
           Posix_Tools.Numbers.Invalid_Syntax,
         "parse leading plus invalid in primitive");
      AUnit.Assertions.Assert
        (Posix_Tools.Numbers.Parse_Nonnegative (" 1").Status =
           Posix_Tools.Numbers.Invalid_Syntax,
         "parse whitespace invalid");
   end Test_Numbers;

   procedure Test_Option_Parsing (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Posix_Tools.Arguments.Parsing.Parse_Status;
      Parsed : Posix_Tools.Arguments.Parsing.Result;
      Position : constant Posix_Tools.Arguments.Parsing.Cursor := (Index => 1, Offset => 2);
   begin
      Parsed := Posix_Tools.Arguments.Parsing.Parse_Short (Args ("-abc"), Position, "abc");
      AUnit.Assertions.Assert
        (Parsed.Status = Posix_Tools.Arguments.Parsing.Option
         and then Parsed.Name = 'a'
         and then Parsed.Next.Index = 1
         and then Parsed.Next.Offset = 3,
         "parse grouped first option");

      Parsed := Posix_Tools.Arguments.Parsing.Parse_Short (Args ("-abc"), Parsed.Next, "abc");
      AUnit.Assertions.Assert
        (Parsed.Status = Posix_Tools.Arguments.Parsing.Option
         and then Parsed.Name = 'b'
         and then Parsed.Next.Index = 1
         and then Parsed.Next.Offset = 4,
         "parse grouped second option");

      Parsed := Posix_Tools.Arguments.Parsing.Parse_Short (Args ("-n10"), Position, "n", "n");
      AUnit.Assertions.Assert
        (Parsed.Status = Posix_Tools.Arguments.Parsing.Option
         and then Parsed.Name = 'n'
         and then Ada.Strings.Unbounded.To_String (Parsed.Text) = "10"
         and then Parsed.Next.Index = 2,
         "parse attached option argument");

      Parsed := Posix_Tools.Arguments.Parsing.Parse_Short (Args ("-n", "10"), Position, "n", "n");
      AUnit.Assertions.Assert
        (Parsed.Status = Posix_Tools.Arguments.Parsing.Option
         and then Ada.Strings.Unbounded.To_String (Parsed.Text) = "10"
         and then Parsed.Next.Index = 3,
         "parse separate option argument");

      Parsed := Posix_Tools.Arguments.Parsing.Parse_Short (Args ("--"), Position, "a");
      AUnit.Assertions.Assert
        (Parsed.Status = Posix_Tools.Arguments.Parsing.End_Of_Options,
         "parse end-of-options");

      Parsed := Posix_Tools.Arguments.Parsing.Parse_Short (Args ("-"), Position, "a");
      AUnit.Assertions.Assert
        (Parsed.Status = Posix_Tools.Arguments.Parsing.Operand
         and then Ada.Strings.Unbounded.To_String (Parsed.Text) = "-",
         "parse lone hyphen operand");

      Parsed := Posix_Tools.Arguments.Parsing.Parse_Short (Args ("-x"), Position, "a");
      AUnit.Assertions.Assert
        (Parsed.Status = Posix_Tools.Arguments.Parsing.Unknown_Option
         and then Parsed.Name = 'x',
         "parse unknown option");

      Parsed := Posix_Tools.Arguments.Parsing.Parse_Short (Args ("-n"), Position, "n", "n");
      AUnit.Assertions.Assert
        (Parsed.Status = Posix_Tools.Arguments.Parsing.Missing_Argument
         and then Parsed.Name = 'n',
         "parse missing option argument");
   end Test_Option_Parsing;

   procedure Test_Paths (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert (Posix_Tools.Paths.Basename ("") = "", "basename empty");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Basename ("/") = "/", "basename root");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Basename ("///") = "/", "basename repeated root");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Basename ("file") = "file", "basename simple");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Basename ("a/b/") = "b", "basename trailing slash");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Basename ("a//b") = "b", "basename repeated separator");
      AUnit.Assertions.Assert
        (Posix_Tools.Paths.Basename ("/tmp/file.txt", ".txt") = "file",
         "basename suffix");
      AUnit.Assertions.Assert
        (Posix_Tools.Paths.Basename ("/tmp/file.txt", "file.txt") = "file.txt",
         "basename suffix equal full name not removed");
      AUnit.Assertions.Assert
        (Posix_Tools.Paths.Basename ("/tmp/file.txt", "") = "file.txt",
         "basename empty suffix");
      AUnit.Assertions.Assert
        (Posix_Tools.Paths.Basename ("//tmp//file") = "file",
         "basename two leading slash policy");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Basename ("a\b") = "a\b", "basename backslash");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Dirname ("") = ".", "dirname empty");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Dirname ("file") = ".", "dirname no slash");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Dirname ("/") = "/", "dirname root");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Dirname ("///") = "/", "dirname repeated root");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Dirname ("a/b/") = "a", "dirname trailing slash");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Dirname ("a//b") = "a", "dirname repeated separator");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Dirname ("/tmp/file") = "/tmp", "dirname absolute");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Dirname ("//tmp") = "/", "dirname two slash policy");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Dirname ("//a/b/") = "/a", "dirname nested two slash policy");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Dirname ("a\b") = ".", "dirname backslash");
   end Test_Paths;

   procedure Test_Path_Properties (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;

      Seed : Word_32 := 16#5054_0001#;

      function Contains_Slash (Text : String) return Boolean is
      begin
         for Ch of Text loop
            if Ch = '/' then
               return True;
            end if;
         end loop;

         return False;
      end Contains_Slash;

      function Ends_With_Slash (Text : String) return Boolean is
      begin
         return Text /= "" and then Text (Text'Last) = '/';
      end Ends_With_Slash;

      function Next_Value return Word_32 is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Seed;
      end Next_Value;

      function Random_Natural (Modulo : Positive) return Natural is
      begin
         return Natural (Next_Value mod Word_32 (Modulo));
      end Random_Natural;

      function Generated_Path return String is
         Alphabet : constant String := "/abc.\";
         Length   : constant Natural := Random_Natural (41);
         Result   : Ada.Strings.Unbounded.Unbounded_String;
      begin
         for I in 1 .. Length loop
            Ada.Strings.Unbounded.Append
              (Result, Alphabet (Alphabet'First + Random_Natural (Alphabet'Length)));
         end loop;

         return Ada.Strings.Unbounded.To_String (Result);
      end Generated_Path;
   begin
      for Case_Index in 1 .. 256 loop
         declare
            Path  : constant String := Generated_Path;
            Base  : constant String := Posix_Tools.Paths.Basename (Path);
            Dir   : constant String := Posix_Tools.Paths.Dirname (Path);
            Label : constant String :=
              "seed 0x50540001 case" & Integer'Image (Case_Index) & " path '" & Path & "'";
         begin
            AUnit.Assertions.Assert
              (Base = "/" or else not Contains_Slash (Base),
               "basename is a single lexical component for " & Label);
            AUnit.Assertions.Assert
              (Dir = "/" or else Dir = "." or else not Ends_With_Slash (Dir),
               "dirname has no trailing slash except root for " & Label);

            if not Contains_Slash (Path) then
               AUnit.Assertions.Assert
                 (Base = Path,
                  "basename preserves slash-free path for " & Label);
               AUnit.Assertions.Assert
                 (Dir = ".",
                  "dirname of slash-free path is dot for " & Label);
            end if;
         end;
      end loop;
   end Test_Path_Properties;

   procedure Test_Stream_File_Fixture (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Ada.Streams.Stream_Element;
      use type Ada.Streams.Stream_Element_Offset;
      Path   : constant String :=
        (if Ada.Directories.Exists ("fixtures") then
            "fixtures/reg-cat-0001.bin"
         else
            "../fixtures/reg-cat-0001.bin");
      File   : Ada.Streams.Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 3);
      Last   : Ada.Streams.Stream_Element_Offset;
   begin
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Buffer :=
        [1 => Ada.Streams.Stream_Element (Character'Pos ('A')),
         2 => 0,
         3 => Ada.Streams.Stream_Element (Character'Pos ('B'))];
      Ada.Streams.Stream_IO.Write (File, Buffer);
      Ada.Streams.Stream_IO.Close (File);

      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      Ada.Streams.Stream_IO.Read (File, Buffer, Last);
      Ada.Streams.Stream_IO.Close (File);

      AUnit.Assertions.Assert (Last = 3, "REG-CAT-0001 fixture length");
      AUnit.Assertions.Assert
        (Buffer (1) = Ada.Streams.Stream_Element (Character'Pos ('A'))
         and then Buffer (2) = 0
         and then Buffer (3) = Ada.Streams.Stream_Element (Character'Pos ('B')),
         "REG-CAT-0001 fixture bytes");
   end Test_Stream_File_Fixture;

   procedure Test_Stream_Line_Split (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Ada.Containers.Count_Type;
      Segments : constant Posix_Tools.Streams.Lines.Segment_Vector :=
        Posix_Tools.Streams.Lines.Split_LF_Segments
          ("A" & Character'Val (10) & "B" & Character'Val (0) & "C");
   begin
      AUnit.Assertions.Assert (Segments.Length = 2, "line segment count");
      AUnit.Assertions.Assert
        (Segments.Element (1) = "A" & Character'Val (10),
         "terminated segment keeps LF");
      AUnit.Assertions.Assert
        (Segments.Element (2) = "B" & Character'Val (0) & "C",
         "final partial segment preserves bytes without LF");
   end Test_Stream_Line_Split;

   procedure Test_Stream_Line_Properties (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Ada.Containers.Count_Type;
      type Word_32 is mod 2 ** 32;

      Seed : Word_32 := 16#5054_0002#;

      function Ends_With_LF (Text : String) return Boolean is
      begin
         return Text /= "" and then Text (Text'Last) = Character'Val (10);
      end Ends_With_LF;

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
         Length : constant Natural := Random_Natural (129);
         Result : Ada.Strings.Unbounded.Unbounded_String;
      begin
         for I in 1 .. Length loop
            if Random_Natural (5) = 0 then
               Ada.Strings.Unbounded.Append (Result, Character'Val (10));
            else
               Ada.Strings.Unbounded.Append (Result, Character'Val (Random_Natural (256)));
            end if;
         end loop;

         return Ada.Strings.Unbounded.To_String (Result);
      end Generated_Bytes;
   begin
      for Case_Index in 1 .. 256 loop
         declare
            Input : constant String := Generated_Bytes;
            Segments : constant Posix_Tools.Streams.Lines.Segment_Vector :=
              Posix_Tools.Streams.Lines.Split_LF_Segments (Input);
            Reassembled : Ada.Strings.Unbounded.Unbounded_String;
            Label : constant String := "seed 0x50540002 case" & Integer'Image (Case_Index);
         begin
            for Segment of Segments loop
               Ada.Strings.Unbounded.Append (Reassembled, Segment);
            end loop;

            AUnit.Assertions.Assert
              (Ada.Strings.Unbounded.To_String (Reassembled) = Input,
               "LF segments reassemble byte-for-byte for " & Label);

            if Input = "" then
               AUnit.Assertions.Assert (Segments.Length = 0, "empty input has no segments for " & Label);
            else
               for I in 1 .. Natural (Segments.Length) loop
                  declare
                     Segment : constant String := Segments.Element (I);
                  begin
                     AUnit.Assertions.Assert (Segment /= "", "no empty segment for " & Label);
                     if I < Natural (Segments.Length) or else Ends_With_LF (Input) then
                        AUnit.Assertions.Assert
                          (Ends_With_LF (Segment),
                           "non-final or delimiter-final segment ends LF for " & Label);
                     else
                        AUnit.Assertions.Assert
                          (not Ends_With_LF (Segment),
                           "final partial segment has no added LF for " & Label);
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;
   end Test_Stream_Line_Properties;

   procedure Test_Stream_Counting (T : in out Fixture) is
      pragma Unreferenced (T);
      State  : Posix_Tools.Streams.Counting.Counter;
      Counts : Posix_Tools.Streams.Counting.Counts;
   begin
      Posix_Tools.Streams.Counting.Process (State, "A" & Character'Val (0));
      Posix_Tools.Streams.Counting.Process (State, "B" & Character'Val (10) & " C");
      Counts := Posix_Tools.Streams.Counting.Snapshot (State);

      AUnit.Assertions.Assert (Counts.Bytes = 6, "byte count includes NUL and LF");
      AUnit.Assertions.Assert (Counts.Lines = 1, "line count counts only LF");
      AUnit.Assertions.Assert (Counts.Words = 2, "word count follows ASCII whitespace policy");
   end Test_Stream_Counting;

   procedure Test_Stream_UTF_8_Counting (T : in out Fixture) is
      pragma Unreferenced (T);
      State  : Posix_Tools.Streams.Counting.Counter;
      Bad_State : Posix_Tools.Streams.Counting.Counter;
      Surrogate_State : Posix_Tools.Streams.Counting.Counter;
      Out_Of_Range_State : Posix_Tools.Streams.Counting.Counter;
      Counts : Posix_Tools.Streams.Counting.Counts;
   begin
      Posix_Tools.Streams.Counting.Process (State, "A ");
      Posix_Tools.Streams.Counting.Process (State, Character'Val (16#C3#) & Character'Val (16#A6#));
      Posix_Tools.Streams.Counting.Process
        (State, Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#83#) & "B");
      Posix_Tools.Streams.Counting.Finish_Text (State);
      Counts := Posix_Tools.Streams.Counting.Snapshot (State);

      AUnit.Assertions.Assert (not Posix_Tools.Streams.Counting.Text_Invalid (State), "valid UTF-8");
      AUnit.Assertions.Assert (Counts.Bytes = 8, "UTF-8 byte count");
      AUnit.Assertions.Assert (Counts.Characters = 5, "UTF-8 character count");
      AUnit.Assertions.Assert (Counts.Words = 3, "Unicode whitespace separates words");

      Posix_Tools.Streams.Counting.Process (Bad_State, "" & Character'Val (16#C3#));
      Posix_Tools.Streams.Counting.Finish_Text (Bad_State);
      AUnit.Assertions.Assert (Posix_Tools.Streams.Counting.Text_Invalid (Bad_State), "incomplete UTF-8");

      Posix_Tools.Streams.Counting.Process
        (Surrogate_State,
         Character'Val (16#ED#) & Character'Val (16#A0#) & Character'Val (16#80#));
      Posix_Tools.Streams.Counting.Finish_Text (Surrogate_State);
      AUnit.Assertions.Assert
        (Posix_Tools.Streams.Counting.Text_Invalid (Surrogate_State),
         "surrogate UTF-8 rejected");

      Posix_Tools.Streams.Counting.Process
        (Out_Of_Range_State,
         Character'Val (16#F4#) & Character'Val (16#90#)
         & Character'Val (16#80#) & Character'Val (16#80#));
      Posix_Tools.Streams.Counting.Finish_Text (Out_Of_Range_State);
      AUnit.Assertions.Assert
        (Posix_Tools.Streams.Counting.Text_Invalid (Out_Of_Range_State),
         "out-of-range UTF-8 rejected");

      declare
         Decoder : Posix_Tools.Text.UTF_8.Decoder;
         Status  : Posix_Tools.Text.UTF_8.Decode_Status;
         Code    : Long_Long_Integer;
      begin
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#E2#, Status, Code);
         AUnit.Assertions.Assert (Status = Posix_Tools.Text.UTF_8.Need_More, "decoder first byte waits");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#82#, Status, Code);
         AUnit.Assertions.Assert (Status = Posix_Tools.Text.UTF_8.Need_More, "decoder second byte waits");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#AC#, Status, Code);
         AUnit.Assertions.Assert
           (Status = Posix_Tools.Text.UTF_8.Complete and then Code = 16#20AC#,
            "decoder completes euro sign");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#C0#, Status, Code);
         AUnit.Assertions.Assert (Status = Posix_Tools.Text.UTF_8.Invalid, "decoder rejects overlong starter");
      end;

      AUnit.Assertions.Assert
        (Posix_Tools.Text.Classification.Unicode_Version = "15.1.0",
         "classification Unicode version recorded");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Classification.Unicode_Source =
           "Unicode Character Database PropList.txt White_Space property",
         "classification Unicode source recorded");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Classification.Is_Whitespace (16#2003#),
         "classification includes em space");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Classification.Is_Whitespace (Character'Pos ('A')),
         "classification excludes letter");

      for Range_Value of Posix_Tools.Text.Whitespace_Data.White_Space_Ranges loop
         AUnit.Assertions.Assert
           (Posix_Tools.Text.Classification.Is_Whitespace (Range_Value.First),
            "classification includes range first");
         AUnit.Assertions.Assert
           (Posix_Tools.Text.Classification.Is_Whitespace (Range_Value.Last),
            "classification includes range last");
         AUnit.Assertions.Assert
           (Posix_Tools.Text.Classification.Is_Whitespace
              (Range_Value.First + (Range_Value.Last - Range_Value.First) / 2),
            "classification includes range midpoint");
      end loop;
   end Test_Stream_UTF_8_Counting;

   procedure Test_Version (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Posix_Tools.Version.Version_String'Length > 0,
         "version synchronized");
   end Test_Version;
end Basic_Tests;
