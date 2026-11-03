with Ada.Containers;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Arguments.Parsing;
with Posix_Tools.Counts;
with Posix_Tools.Exit_Status;
with Posix_Tools.Extension_Options;
with Posix_Tools.Numbers;
with Posix_Tools.Option_Parsing;
with Posix_Tools.Paths;
with Posix_Tools.Streams.Counting;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Tail_Rings;
with Posix_Tools.Text.Line_Breaks;
with Posix_Tools.Text.Locale_Fields;
with Posix_Tools.Version;
with Posix_Tools.Wc_Fields;
with Test_Support;

package body Basic_Tests is
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

   procedure Test_Numbers (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Posix_Tools.Numbers.Count;
      use type Posix_Tools.Numbers.Parse_Status;
      Parsed : Posix_Tools.Numbers.Parse_Result;
   begin
      AUnit.Assertions.Assert
        (Posix_Tools.Numbers.Is_Decimal_Digit ('0'),
         "zero is a decimal digit");
      AUnit.Assertions.Assert
        (Posix_Tools.Numbers.Is_Decimal_Digit ('9'),
         "nine is a decimal digit");
      AUnit.Assertions.Assert
        (not Posix_Tools.Numbers.Is_Decimal_Digit ('x'),
         "letter is not a decimal digit");
      AUnit.Assertions.Assert
        (Posix_Tools.Numbers.Digit_Value ('7') = 7,
         "digit value");
      AUnit.Assertions.Assert
        (Posix_Tools.Numbers.Contains_Only_Decimal_Digits ("0123456789"),
         "all digits accepted");
      AUnit.Assertions.Assert
        (not Posix_Tools.Numbers.Contains_Only_Decimal_Digits ("12x"),
         "mixed text rejected");

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

   procedure Test_Exit_Status (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Posix_Tools.Exit_Status.Code;
   begin
      AUnit.Assertions.Assert
        (Posix_Tools.Exit_Status.Classify_Xargs_Status (False, 0) =
           Posix_Tools.Exit_Status.Utility_Not_Found,
         "xargs classifier maps no-run utility");
      AUnit.Assertions.Assert
        (Posix_Tools.Exit_Status.Classify_Xargs_Status (True, 1) =
           Posix_Tools.Exit_Status.Xargs_Utility_Failed,
         "xargs classifier maps failed utility");
      AUnit.Assertions.Assert
        (Posix_Tools.Exit_Status.Classify_Xargs_Status (True, 125) =
           Posix_Tools.Exit_Status.Xargs_Utility_Failed,
         "xargs classifier maps failed utility upper band");
      AUnit.Assertions.Assert
        (Posix_Tools.Exit_Status.Classify_Xargs_Status (True, 126) =
           Posix_Tools.Exit_Status.Utility_Cannot_Invoke,
         "xargs classifier maps cannot invoke");
      AUnit.Assertions.Assert
        (Posix_Tools.Exit_Status.Classify_Xargs_Status (True, 127) =
           Posix_Tools.Exit_Status.Utility_Not_Found,
         "xargs classifier maps utility not found");
      AUnit.Assertions.Assert
        (Posix_Tools.Exit_Status.Classify_Xargs_Status (True, 255) =
           Posix_Tools.Exit_Status.Xargs_Utility_Requested_Stop,
         "xargs classifier maps requested stop");
      AUnit.Assertions.Assert
        (Posix_Tools.Exit_Status.Classify_Xargs_Status (True, 0) =
           Posix_Tools.Exit_Status.Operational_Failure,
         "xargs classifier maps neutral utility status");
      declare
         use type Posix_Tools.Extension_Options.Extension_Action;
      begin
         AUnit.Assertions.Assert
           (Posix_Tools.Extension_Options.Intercept_Action (0, "--help") =
              Posix_Tools.Extension_Options.No_Extension,
            "extension option ignores empty argument lists");
         AUnit.Assertions.Assert
           (Posix_Tools.Extension_Options.Intercept_Action (2, "--help") =
              Posix_Tools.Extension_Options.Render_Help,
            "conventional extension option accepts help with trailing operands");
         AUnit.Assertions.Assert
           (Posix_Tools.Extension_Options.Intercept_Action (2, "--help", Conventional => False) =
              Posix_Tools.Extension_Options.No_Extension,
            "non-conventional extension option requires a sole argument");
         AUnit.Assertions.Assert
           (Posix_Tools.Extension_Options.Intercept_Action (1, "--posix-tools-identify") =
              Posix_Tools.Extension_Options.Render_Identity,
            "extension option accepts identity when sole argument");
         AUnit.Assertions.Assert
           (Posix_Tools.Extension_Options.Intercept_Action (2, "--posix-tools-identify") =
              Posix_Tools.Extension_Options.No_Extension,
            "extension option rejects identity with trailing operands");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Locale_Fields.Catalog_Path
           (Here => True, Parent => True, Grandparent => True) =
             "common/messages/posix_tools.catalog",
         "catalog path prefers repository-local catalog");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Locale_Fields.Catalog_Path
           (Here => False, Parent => True, Grandparent => True) =
             "../common/messages/posix_tools.catalog",
         "catalog path falls back to parent checkout");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Locale_Fields.Catalog_Path
           (Here => False, Parent => False, Grandparent => True) =
             "../../common/messages/posix_tools.catalog",
         "catalog path falls back to grandparent checkout");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Locale_Fields.Catalog_Path
           (Here => False, Parent => False, Grandparent => False) =
             "common/messages/posix_tools.catalog",
         "catalog path default stays repository-local");
   end Test_Exit_Status;

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

      declare
         use type Posix_Tools.Option_Parsing.Parse_Status;
         use type Posix_Tools.Option_Parsing.Text_Source;
         Decision          : constant Posix_Tools.Option_Parsing.Decision :=
           Posix_Tools.Option_Parsing.Decide_Short
             ("-n10", (Index => 1, Offset => 2), 1, "n", "n");
         Following         : constant Posix_Tools.Option_Parsing.Decision :=
           Posix_Tools.Option_Parsing.Decide_Short
             ("-n", (Index => 1, Offset => 2), 2, "n", "n");
         Operand_Decision  : constant Posix_Tools.Option_Parsing.Decision :=
           Posix_Tools.Option_Parsing.Decide_Short
             ("file", (Index => 1, Offset => 2), 1, "n", "n");
         Unknown_Decision  : constant Posix_Tools.Option_Parsing.Decision :=
           Posix_Tools.Option_Parsing.Decide_Short
             ("-x", (Index => 1, Offset => 2), 1, "n", "n");
         Done_Decision     : constant Posix_Tools.Option_Parsing.Decision :=
           Posix_Tools.Option_Parsing.Decide_Short
             ("-n", (Index => 1, Offset => 3), 1, "n", "");
      begin
         AUnit.Assertions.Assert
           (Decision.Status = Posix_Tools.Option_Parsing.Option
            and then Decision.Source = Posix_Tools.Option_Parsing.Inline_Remainder
            and then Decision.Inline_First = 3
            and then Posix_Tools.Option_Parsing.Cursor_Progresses
              (Decision, (Index => 1, Offset => 2), 1)
            and then Posix_Tools.Option_Parsing.Source_Is_Consistent
              (Decision, (Index => 1, Offset => 2), "-n10", 1)
            and then Posix_Tools.Option_Parsing.Status_Is_Consistent (Decision),
            "proved option decision finds inline option argument");
         AUnit.Assertions.Assert
           (Following.Status = Posix_Tools.Option_Parsing.Option
            and then Following.Source = Posix_Tools.Option_Parsing.Following_Argument
            and then Following.Next.Index = 3
            and then Following.Next.Offset = 2
            and then Posix_Tools.Option_Parsing.Cursor_Progresses
              (Following, (Index => 1, Offset => 2), 2)
            and then Posix_Tools.Option_Parsing.Source_Is_Consistent
              (Following, (Index => 1, Offset => 2), "-n", 2)
            and then Posix_Tools.Option_Parsing.Status_Is_Consistent (Following),
            "proved option decision finds following option argument");
         AUnit.Assertions.Assert
           (Operand_Decision.Status = Posix_Tools.Option_Parsing.Operand
            and then Operand_Decision.Source = Posix_Tools.Option_Parsing.Current_Argument
            and then Operand_Decision.Name = Character'Val (0)
            and then Posix_Tools.Option_Parsing.Source_Is_Consistent
              (Operand_Decision, (Index => 1, Offset => 2), "file", 1)
            and then Posix_Tools.Option_Parsing.Status_Is_Consistent (Operand_Decision),
            "proved option decision marks current argument operands");
         AUnit.Assertions.Assert
           (Unknown_Decision.Status = Posix_Tools.Option_Parsing.Unknown_Option
            and then Unknown_Decision.Source = Posix_Tools.Option_Parsing.No_Text
            and then Unknown_Decision.Name = 'x',
            "proved option decision marks unknown options without text");
         AUnit.Assertions.Assert
           (Done_Decision.Status = Posix_Tools.Option_Parsing.Done
            and then Done_Decision.Source = Posix_Tools.Option_Parsing.No_Text
            and then Done_Decision.Next.Index = 2
            and then Done_Decision.Next.Offset = 2,
            "proved option decision advances after exhausted groups");
      end;
   end Test_Option_Parsing;

   procedure Test_Option_Parsing_Properties (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Posix_Tools.Arguments.Parsing.Parse_Status;

      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;

      Initial_Seed : constant Word_32 := 16#4F50_5453#;
      Seed : Word_32 := Initial_Seed;

      function Next_Value return Natural is
      begin
         Test_Support.Advance (Seed);
         return Natural ((Seed / 16#0100_0000#) mod 256);
      end Next_Value;

      function Accepted_Option return Character is
         Choices : constant String := "abc";
      begin
         return Choices (Choices'First + Next_Value mod Choices'Length);
      end Accepted_Option;

      function Unknown_Option return Character is
         Choices : constant String := "xyz";
      begin
         return Choices (Choices'First + Next_Value mod Choices'Length);
      end Unknown_Option;
   begin
      for Case_Index in 1 .. 32 loop
         declare
            Length : constant Natural := 1 + Next_Value mod 8;
            Text   : String (1 .. Length + 1);
            Parsed : Posix_Tools.Arguments.Parsing.Result;
            Cursor : Posix_Tools.Arguments.Parsing.Cursor := (Index => 1, Offset => 2);
         begin
            Text (Text'First) := '-';
            for I in 2 .. Text'Last loop
               Text (I) := Accepted_Option;
            end loop;

            for I in 2 .. Text'Last loop
               Parsed := Posix_Tools.Arguments.Parsing.Parse_Short (Args (Text), Cursor, "abc");
               AUnit.Assertions.Assert
                 (Parsed.Status = Posix_Tools.Arguments.Parsing.Option
                  and then Parsed.Name = Text (I),
                  "option parser property " & Test_Support.Seed_Label (Initial_Seed) & " case"
                  & Natural'Image (Case_Index) & " accepted option");
               Cursor := Parsed.Next;
            end loop;

            Parsed := Posix_Tools.Arguments.Parsing.Parse_Short (Args (Text), Cursor, "abc");
            AUnit.Assertions.Assert
              (Parsed.Status = Posix_Tools.Arguments.Parsing.Done,
               "option parser property " & Test_Support.Seed_Label (Initial_Seed) & " case"
               & Natural'Image (Case_Index) & " done");
         end;
      end loop;

      for Case_Index in 1 .. 16 loop
         declare
            Ch     : constant Character := Unknown_Option;
            Parsed : constant Posix_Tools.Arguments.Parsing.Result :=
              Posix_Tools.Arguments.Parsing.Parse_Short (Args ("-" & Ch), (Index => 1, Offset => 2), "abc");
         begin
            AUnit.Assertions.Assert
              (Parsed.Status = Posix_Tools.Arguments.Parsing.Unknown_Option
               and then Parsed.Name = Ch,
               "option parser property " & Test_Support.Seed_Label (Initial_Seed) & " case"
               & Natural'Image (Case_Index) & " unknown option");
         end;
      end loop;
   end Test_Option_Parsing_Properties;

   procedure Test_Count_Windows (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Posix_Tools.Numbers.Count;
   begin
      AUnit.Assertions.Assert
        (Posix_Tools.Counts.Suffix_Start (Total => 0, Requested => 0) = 1,
         "empty suffix starts after the empty input");
      AUnit.Assertions.Assert
        (Posix_Tools.Counts.Suffix_Start (Total => 0, Requested => 3) = 1,
         "oversized suffix of empty input starts after the empty input");
      AUnit.Assertions.Assert
        (Posix_Tools.Counts.Suffix_Start (Total => 8, Requested => 0) = 9,
         "zero suffix count starts after the input");
      AUnit.Assertions.Assert
        (Posix_Tools.Counts.Suffix_Start (Total => 8, Requested => 3) = 6,
         "short suffix starts at total minus count plus one");
      AUnit.Assertions.Assert
        (Posix_Tools.Counts.Suffix_Start (Total => 8, Requested => 8) = 1,
         "full suffix starts at one");
      AUnit.Assertions.Assert
        (Posix_Tools.Counts.Suffix_Start (Total => 8, Requested => 20) = 1,
         "oversized suffix starts at one");
      AUnit.Assertions.Assert
        (Posix_Tools.Counts.Should_Emit_From_Start (Position => 1, Requested => 0),
         "tail +0 emits from first byte");
      AUnit.Assertions.Assert
        (not Posix_Tools.Counts.Should_Emit_From_Start (Position => 2, Requested => 3),
         "tail +3 skips earlier bytes");
      AUnit.Assertions.Assert
        (Posix_Tools.Counts.Should_Emit_From_Start (Position => 3, Requested => 3),
         "tail +3 emits the requested byte");
      AUnit.Assertions.Assert
        (Posix_Tools.Counts.Rounded_Units (-1, 512) = 0
         and then Posix_Tools.Counts.Rounded_Units (0, 512) = 0
         and then Posix_Tools.Counts.Rounded_Units (1, 512) = 1
         and then Posix_Tools.Counts.Rounded_Units (512, 512) = 1
         and then Posix_Tools.Counts.Rounded_Units (513, 512) = 2
         and then Posix_Tools.Counts.Rounded_Units (Long_Long_Integer'Last, 512) > 0,
         "rounded byte unit counts avoid overflow");
   end Test_Count_Windows;

   procedure Test_Paths (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Posix_Tools.Paths.Is_All_Slashes ("///"),
         "all-slashes predicate accepts repeated root");
      AUnit.Assertions.Assert
        (not Posix_Tools.Paths.Is_All_Slashes ("/tmp"),
         "all-slashes predicate rejects mixed path");
      AUnit.Assertions.Assert
        (Posix_Tools.Paths.Contains_Slash ("a/b"),
         "contains-slash predicate accepts path separator");
      AUnit.Assertions.Assert
        (not Posix_Tools.Paths.Contains_Slash ("a\b"),
         "contains-slash predicate rejects backslash");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Basename ("") = "", "basename empty");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Basename ("/") = "/", "basename root");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Basename ("///") = "/", "basename repeated root");
      AUnit.Assertions.Assert (Posix_Tools.Paths.Basename ("file") = "file", "basename simple");
      AUnit.Assertions.Assert
        (Posix_Tools.Paths.Basename ("file.txt", ".txt") = "file",
         "basename strips suffix without directory");
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
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;

      Initial_Seed : constant Word_32 := 16#5054_0001#;
      Seed : Word_32 := Initial_Seed;

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
         Test_Support.Advance (Seed);
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
              Test_Support.Seed_Label (Initial_Seed) & " case" & Integer'Image (Case_Index) & " path '" & Path & "'";
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

   procedure Test_Tail_Ring_Arithmetic (T : in out Fixture) is
      pragma Unreferenced (T);

      First_Step : constant Posix_Tools.Tail_Rings.Advance_Result :=
        Posix_Tools.Tail_Rings.Advance (First => 1, Last => 4, Current => 1, Filled => 0);
      Wrapped : constant Posix_Tools.Tail_Rings.Advance_Result :=
        Posix_Tools.Tail_Rings.Advance (First => 1, Last => 4, Current => 4, Filled => 4);
      Saturated : constant Posix_Tools.Tail_Rings.Advance_Result :=
        Posix_Tools.Tail_Rings.Advance (First => 1, Last => 4, Current => 2, Filled => 4);
   begin
      AUnit.Assertions.Assert
        (Posix_Tools.Tail_Rings.Capacity (1, 4) = 4,
         "ring capacity");
      AUnit.Assertions.Assert
        (not Posix_Tools.Tail_Rings.Is_Full (First => 1, Last => 4, Filled => 3),
         "partially filled ring is not full");
      AUnit.Assertions.Assert
        (Posix_Tools.Tail_Rings.Is_Full (First => 1, Last => 4, Filled => 4),
         "filled ring is full");
      AUnit.Assertions.Assert
        (not Posix_Tools.Tail_Rings.Will_Wrap (Current => 3, Last => 4),
         "ring position before last does not wrap");
      AUnit.Assertions.Assert
        (Posix_Tools.Tail_Rings.Will_Wrap (Current => 4, Last => 4),
         "ring position at last wraps");
      AUnit.Assertions.Assert
        (First_Step.Next = 2 and then First_Step.Filled = 1,
         "first write advances and fills");
      AUnit.Assertions.Assert
        (Wrapped.Next = 1 and then Wrapped.Filled = 4,
         "full ring wraps without increasing fill");
      AUnit.Assertions.Assert
        (Saturated.Next = 3 and then Saturated.Filled = 4,
         "full ring advances without exceeding capacity");
   end Test_Tail_Ring_Arithmetic;

   procedure Test_Wc_Field_Arithmetic (T : in out Fixture) is
      pragma Unreferenced (T);

      Default_Selection : constant Posix_Tools.Wc_Fields.Count_Selection :=
        (Lines => True, Words => True, Bytes => True, Characters => False, Max_Line_Length => False);
      Text_Selection : constant Posix_Tools.Wc_Fields.Count_Selection :=
        (Lines => False, Words => True, Bytes => False, Characters => True, Max_Line_Length => False);
      Raw_Selection : constant Posix_Tools.Wc_Fields.Count_Selection :=
        (Lines => True, Words => False, Bytes => True, Characters => False, Max_Line_Length => False);
      Line_Length_Selection : constant Posix_Tools.Wc_Fields.Count_Selection :=
        (Lines => False, Words => False, Bytes => False, Characters => False, Max_Line_Length => True);
      Character_Selection : constant Posix_Tools.Wc_Fields.Count_Selection :=
        (Lines => False, Words => False, Bytes => False, Characters => True, Max_Line_Length => False);
      Empty_Selection : constant Posix_Tools.Wc_Fields.Count_Selection :=
        (Lines => False, Words => False, Bytes => False, Characters => False, Max_Line_Length => False);
   begin
      AUnit.Assertions.Assert (Posix_Tools.Wc_Fields.Decimal_Width (0) = 1, "zero width");
      AUnit.Assertions.Assert (Posix_Tools.Wc_Fields.Decimal_Width (9) = 1, "single digit width");
      AUnit.Assertions.Assert (Posix_Tools.Wc_Fields.Decimal_Width (10) = 2, "two digit width");
      AUnit.Assertions.Assert
        (Posix_Tools.Wc_Fields.Decimal_Width (Long_Long_Integer'Last) = 19,
         "maximum signed count width");
      AUnit.Assertions.Assert
        (Posix_Tools.Wc_Fields.Selected_Field_Count (Default_Selection) = 3,
         "default field count");
      AUnit.Assertions.Assert
        (Posix_Tools.Wc_Fields.Selected_Field_Count (Line_Length_Selection) = 1,
         "maximum-line-length field count");
      AUnit.Assertions.Assert
        (Posix_Tools.Wc_Fields.Needs_Text_Decoding (Text_Selection),
         "text fields require decoding");
      AUnit.Assertions.Assert
        (Posix_Tools.Wc_Fields.Needs_Text_Decoding (Line_Length_Selection),
         "maximum-line-length field requires decoding");
      AUnit.Assertions.Assert
        (Posix_Tools.Wc_Fields.Needs_Text_Decoding (Character_Selection),
         "character field requires decoding");
      AUnit.Assertions.Assert
        (not Posix_Tools.Wc_Fields.Needs_Text_Decoding (Raw_Selection),
         "raw fields do not require decoding");
      AUnit.Assertions.Assert
        (not Posix_Tools.Wc_Fields.Needs_Text_Decoding (Empty_Selection),
         "empty field selection does not require decoding");
   end Test_Wc_Field_Arithmetic;

   procedure Test_Stream_File_Fixture (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Ada.Streams.Stream_Element;
      use type Ada.Streams.Stream_Element_Offset;
      Path   : constant String := Test_Support.Work_Path ("reg-cat-0001.bin");
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
        (Posix_Tools.Text.Line_Breaks.Is_LF (Character'Val (10)),
         "LF predicate accepts line feed");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Line_Breaks.Is_LF (Character'Val (13)),
         "LF predicate rejects carriage return");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Line_Breaks.LF_Count
           ("A" & Character'Val (10) & "B" & Character'Val (10)) = 2,
         "LF count");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Line_Breaks.LF_Segment_Count
           ("A" & Character'Val (10) & "B") = 2,
         "partial final LF segment count");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Line_Breaks.LF_Segment_Count
           ("A" & Character'Val (10)) = 1,
         "terminated LF segment count");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Line_Breaks.LF_Segment_Last_From
           ("A" & Character'Val (10) & "B", 1) = 2,
         "terminated LF segment last index");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Line_Breaks.LF_Segment_Last_From
           ("A" & Character'Val (10) & "B", 3) = 3,
         "final partial LF segment last index");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Line_Breaks.Line_Number_Through
           ("A" & Character'Val (10) & "B", 1) = 1,
         "line number before first LF");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Line_Breaks.Line_Number_Through
           ("A" & Character'Val (10) & "B", 3) = 2,
         "line number after first LF");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
           ("A" & Character'Val (13)) = "A",
         "trailing CR is removed");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Line_Breaks.Without_Trailing_CR ("A") = "A",
         "non-CR line is unchanged");
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
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;

      Initial_Seed : constant Word_32 := 16#5054_0002#;
      Seed : Word_32 := Initial_Seed;

      function Next_Value return Word_32 is
      begin
         Test_Support.Advance (Seed);
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
            Label : constant String := Test_Support.Seed_Label (Initial_Seed) & " case" & Integer'Image (Case_Index);
         begin
            for Segment of Segments loop
               Ada.Strings.Unbounded.Append (Reassembled, Segment);
            end loop;

            AUnit.Assertions.Assert
              (Ada.Strings.Unbounded.To_String (Reassembled) = Input,
               "LF segments reassemble byte-for-byte for " & Label);
            AUnit.Assertions.Assert
              (Posix_Tools.Text.Line_Breaks.LF_Segment_Count (Input) =
                 Long_Long_Integer (Segments.Length),
               "LF segment count matches splitter for " & Label);

            if Input = "" then
               AUnit.Assertions.Assert (Segments.Length = 0, "empty input has no segments for " & Label);
            else
               for I in 1 .. Natural (Segments.Length) loop
                  declare
                     Segment : constant String := Segments.Element (I);
                  begin
                     AUnit.Assertions.Assert (Segment /= "", "no empty segment for " & Label);
                     if I < Natural (Segments.Length) or else Posix_Tools.Text.Line_Breaks.Ends_With_LF (Input) then
                        AUnit.Assertions.Assert
                          (Posix_Tools.Text.Line_Breaks.Ends_With_LF (Segment),
                           "non-final or delimiter-final segment ends LF for " & Label);
                     else
                        AUnit.Assertions.Assert
                          (not Posix_Tools.Text.Line_Breaks.Ends_With_LF (Segment),
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
      AUnit.Assertions.Assert
        (Posix_Tools.Streams.Counting.Saturating_Add (2, 3) = 5,
         "saturating add keeps ordinary sum");
      AUnit.Assertions.Assert
        (Posix_Tools.Streams.Counting.Saturating_Add
           (Long_Long_Integer'Last, 1) = Long_Long_Integer'Last,
         "saturating add clamps overflow");
      AUnit.Assertions.Assert
        (Posix_Tools.Streams.Counting.Maximum (5, 3) = 5,
         "maximum keeps left larger value");
      AUnit.Assertions.Assert
        (Posix_Tools.Streams.Counting.Maximum (3, 5) = 5,
         "maximum keeps right larger value");

      Posix_Tools.Streams.Counting.Process (State, "A" & Character'Val (0));
      Posix_Tools.Streams.Counting.Process (State, "B" & Character'Val (10) & " C");
      Counts := Posix_Tools.Streams.Counting.Snapshot (State);

      AUnit.Assertions.Assert (Counts.Bytes = 6, "byte count includes NUL and LF");
      AUnit.Assertions.Assert (Counts.Lines = 1, "line count counts only LF");
      AUnit.Assertions.Assert (Counts.Words = 2, "word count follows ASCII whitespace policy");
   end Test_Stream_Counting;

   procedure Test_Version (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Posix_Tools.Version.Version_String'Length > 0,
         "version synchronized");
      AUnit.Assertions.Assert
        (Posix_Tools.Version.Is_Version_String (Posix_Tools.Version.Version_String),
         "version predicate accepts release version");
      AUnit.Assertions.Assert
        (not Posix_Tools.Version.Is_Version_String ("0.0.0"),
         "version predicate rejects other version");
      AUnit.Assertions.Assert
        (Posix_Tools.Version.Is_Project_Name (Posix_Tools.Version.Project_Name),
         "project predicate accepts project name");
      AUnit.Assertions.Assert
        (not Posix_Tools.Version.Is_Project_Name ("posix_tools"),
         "project predicate rejects alternate spelling");
   end Test_Version;

end Basic_Tests;
