with Ada.Directories;
with Ada.Containers;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Interfaces;
with Posix_Tools.Arguments;
with Posix_Tools.Arguments.Parsing;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Counts;
with Posix_Tools.Exit_Status;
with Posix_Tools.Extension_Options;
with Posix_Tools.Numbers;
with Posix_Tools.Option_Parsing;
with Posix_Tools.Paths;
with Posix_Tools.Streams.Counting;
with Posix_Tools.Streams.Lines;
with Posix_Tools.Tail_Counts;
with Posix_Tools.Tail_Rings;
with Posix_Tools.Text.Base_Parsing;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Checksum_Lines;
with Posix_Tools.Text.Checksums;
with Posix_Tools.Text.Classification;
with Posix_Tools.Text.Cut_Fields;
with Posix_Tools.Text.DD_Blocks;
with Posix_Tools.Text.DD_Conversion_Engine;
with Posix_Tools.Text.DD_Conversions;
with Posix_Tools.Text.DD_Operands;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Diagnostic_Fields;
with Posix_Tools.Text.Duration_Fields;
with Posix_Tools.Text.Escaping;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.File_Magic_Fields;
with Posix_Tools.Text.File_Operands;
with Posix_Tools.Text.Find_Expressions;
with Posix_Tools.Text.Glob_Fields;
with Posix_Tools.Text.Hex_Digests;
with Posix_Tools.Text.Line_Breaks;
with Posix_Tools.Text.Locale_Fields;
with Posix_Tools.Text.Logical_Paths;
with Posix_Tools.Text.Matching;
with Posix_Tools.Text.Nice_Fields;
with Posix_Tools.Text.NL_Fields;
with Posix_Tools.Text.Numeric_Images;
with Posix_Tools.Text.OD_Formats;
with Posix_Tools.Text.Octal_Modes;
with Posix_Tools.Text.Octal_Parsing;
with Posix_Tools.Text.Owner_Groups;
with Posix_Tools.Text.Paste_Delimiters;
with Posix_Tools.Text.Portable_Paths;
with Posix_Tools.Text.Printf_Escapes;
with Posix_Tools.Text.Seq_Formats;
with Posix_Tools.Text.Signal_Names;
with Posix_Tools.Text.Sort_Modifiers;
with Posix_Tools.Text.Sort_Numeric;
with Posix_Tools.Text.Stat_Formats;
with Posix_Tools.Text.Suffixes;
with Posix_Tools.Text.Tab_Stops;
with Posix_Tools.Text.Test_Operators;
with Posix_Tools.Text.Touch_Fields;
with Posix_Tools.Text.Time_Fields;
with Posix_Tools.Text.Whitespace_Data;
with Posix_Tools.Text.UTF_8;
with Posix_Tools.Text.Xargs_Fields;
with Posix_Tools.Version;
with Posix_Tools.Wc_Fields;

package body Basic_Tests is
   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;
   use type Posix_Tools.Text.UTF_8.Decode_Status;
   use type Posix_Tools.Text.Find_Expressions.Count_Relation;
   use type Posix_Tools.Text.Find_Expressions.Find_Type_Filter;
   use type Posix_Tools.Text.File_Modes.Permission_Mode_Status;
   use type Posix_Tools.Text.NL_Fields.Logical_Section;
   use type Posix_Tools.Text.NL_Fields.Number_Mode;
   use type Posix_Tools.Text.OD_Formats.Address_Base;
   use type Posix_Tools.Text.OD_Formats.Dump_Format_Kind;
   use type Posix_Tools.Text.Signal_Names.Signal_Name;

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

   function Same_Natural (Left, Right : Natural) return Boolean is
   begin
      return Left = Right;
   end Same_Natural;

   function Same_Text (Left, Right : String) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;

      for I in Left'Range loop
         if Left (I) /= Right (Right'First + (I - Left'First)) then
            return False;
         end if;
      end loop;

      return True;
   end Same_Text;

   procedure Test_Command_Inventory (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert (Same_Natural (Posix_Tools.Command_Inventory.Command_Count, 74), "inventory count");
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Executable (1) = "arch", "first command");
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Executable (68) = "unlink", "unlink command");
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Executable (74) = "yes", "last command");
      AUnit.Assertions.Assert
        (Posix_Tools.Command_Inventory.Manifest_Path (2) = "tools/basename/alire.toml",
         "manifest path");
      AUnit.Assertions.Assert
        (Posix_Tools.Command_Inventory.Project_File_Path (70) = "tools/wc/posix_tools_wc.gpr",
         "project file path");
      AUnit.Assertions.Assert
        (Posix_Tools.Command_Inventory.Documentation_Path (58) = "docs/commands/tail.md",
         "documentation path");
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Has_Help (1), "help flag");
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Has_Version (1), "version flag");
      AUnit.Assertions.Assert (Posix_Tools.Command_Inventory.Has_Identity (1), "identity flag");
      AUnit.Assertions.Assert
        (Posix_Tools.Command_Inventory.Posix_Status (58) = "conforming_with_extensions",
         "tail status value");
      AUnit.Assertions.Assert
        (Posix_Tools.Command_Inventory.Posix_Status (70) = "conforming_with_extensions",
         "wc status value");
   end Test_Command_Inventory;

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

      type Word_32 is mod 2 ** 32;

      Seed : Word_32 := 16#4F50_5453#;

      function Next_Value return Natural is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
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
                  "option parser property seed 0x4F505453 case"
                  & Natural'Image (Case_Index) & " accepted option");
               Cursor := Parsed.Next;
            end loop;

            Parsed := Posix_Tools.Arguments.Parsing.Parse_Short (Args (Text), Cursor, "abc");
            AUnit.Assertions.Assert
              (Parsed.Status = Posix_Tools.Arguments.Parsing.Done,
               "option parser property seed 0x4F505453 case"
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
               "option parser property seed 0x4F505453 case"
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
      type Word_32 is mod 2 ** 32;

      Seed : Word_32 := 16#5054_0002#;

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
         AUnit.Assertions.Assert
           (Posix_Tools.Text.UTF_8.Is_Initial (Decoder),
            "decoder starts initial");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#E2#, Status, Code);
         AUnit.Assertions.Assert (Status = Posix_Tools.Text.UTF_8.Need_More, "decoder first byte waits");
         AUnit.Assertions.Assert
           (not Posix_Tools.Text.UTF_8.Is_Initial (Decoder),
            "decoder carries partial sequence");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#82#, Status, Code);
         AUnit.Assertions.Assert (Status = Posix_Tools.Text.UTF_8.Need_More, "decoder second byte waits");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#AC#, Status, Code);
         AUnit.Assertions.Assert
           (Status = Posix_Tools.Text.UTF_8.Complete and then Code = 16#20AC#,
            "decoder completes euro sign");
         AUnit.Assertions.Assert
           (Posix_Tools.Text.UTF_8.Is_Initial (Decoder),
            "decoder resets after complete sequence");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#C0#, Status, Code);
         AUnit.Assertions.Assert (Status = Posix_Tools.Text.UTF_8.Invalid, "decoder rejects overlong starter");
         AUnit.Assertions.Assert
           (Posix_Tools.Text.UTF_8.Is_Initial (Decoder),
            "decoder resets after invalid starter");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#E2#, Status, Code);
         Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos ('A'), Status, Code);
         AUnit.Assertions.Assert
           (Status = Posix_Tools.Text.UTF_8.Invalid
            and then Posix_Tools.Text.UTF_8.Is_Initial (Decoder),
            "decoder rejects invalid continuation and resets");
      end;

      AUnit.Assertions.Assert
        (Same_Text (Posix_Tools.Text.Classification.Unicode_Version, "15.1.0"),
         "classification Unicode version recorded");
      AUnit.Assertions.Assert
        (Same_Text
           (Posix_Tools.Text.Classification.Unicode_Source,
            "Unicode Character Database PropList.txt White_Space property"),
         "classification Unicode source recorded");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Classification.Is_Whitespace (16#2003#),
         "classification includes em space");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Classification.Is_Whitespace (Character'Pos ('A')),
         "classification excludes letter");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Classification.Is_Unicode_Scalar (16#10FFFF#),
         "classification accepts maximum Unicode scalar");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Classification.Is_Unicode_Scalar (16#D800#),
         "classification rejects surrogate scalar");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Classification.Is_Unicode_Scalar (16#110000#),
         "classification rejects value above Unicode range");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Classification.Is_Whitespace (16#D800#),
         "classification rejects surrogate whitespace");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Classification.Is_Whitespace (-1),
         "classification rejects negative whitespace");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank (' '),
         "xargs blank accepts space");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank (Character'Val (9)),
         "xargs blank accepts horizontal tab");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank (Character'Val (10)),
         "xargs blank accepts LF");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank (Character'Val (13)),
         "xargs blank rejects CR");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank ('A'),
         "xargs blank rejects ordinary text");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Alphanumeric ('9')
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Alphanumeric ('Z')
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Alphanumeric ('a'),
         "ASCII alphanumeric accepts digits and letters");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Alpha ('Z')
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Alpha ('a')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Alpha ('9'),
         "ASCII alpha accepts only letters");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Byte_Classes.Is_ASCII_Alphanumeric ('_'),
         "ASCII alphanumeric rejects punctuation");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Control (Character'Val (0))
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Control (Character'Val (127))
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Control (' '),
         "ASCII control range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit ('5')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit ('A'),
         "ASCII digit range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit ('7')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit ('8'),
         "ASCII octal digit range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Graph ('!')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Graph (' '),
         "ASCII graph excludes space");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Lower ('z')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Lower ('Z'),
         "ASCII lower range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Printable ('~')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Printable (Character'Val (127)),
         "ASCII printable range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Punctuation ('!')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Punctuation ('A'),
         "ASCII punctuation range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper ('A')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper ('a'),
         "ASCII upper range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.To_ASCII_Upper ('z') = 'Z'
         and then Posix_Tools.Text.Byte_Classes.To_ASCII_Lower ('A') = 'a',
         "ASCII case conversion values");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit ('F')
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit ('f')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit ('G'),
         "ASCII hex digit range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper_Hex_Digit ('F')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper_Hex_Digit ('f')
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Lower_Hex_Digit ('f')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Lower_Hex_Digit ('F'),
         "ASCII split hex digit ranges");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value ('9') = 9
         and then Posix_Tools.Text.Byte_Classes.ASCII_Digit_Character (0) = '0'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Digit_Character (9) = '9'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Lowercase_Character (0) = 'a'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Lowercase_Character (25) = 'z'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Octal_Digit_Value ('7') = 7
         and then Posix_Tools.Text.Byte_Classes.ASCII_Octal_Digit_Character (7) = '7'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Value ('F') = 15
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Value ('f') = 15,
         "ASCII digit and letter values");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (0) = '0'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (10) = 'a'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (15) = 'f'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (10, Upper => True) = 'A'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (15, Upper => True) = 'F',
         "ASCII hex digit construction");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Checksums.POSIX_Cksum_CRC_32 ("") = 16#FFFF_FFFF#
         and then Posix_Tools.Text.Checksums.POSIX_Cksum_CRC_32 ("abc") = 1_219_131_554,
         "POSIX cksum CRC32");
      declare
         Digest : constant String :=
           "ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789";
         Text_Mode : constant Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line :=
           Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line_Info (Digest & "  file.txt");
         Binary_Mode : constant Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line :=
           Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line_Info (Digest & " *file.txt");
         Empty_Name : constant Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line :=
           Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line_Info (Digest & "  ");
         Bad_Digest : constant Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line :=
           Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line_Info
             ("Z" & Digest (Digest'First + 1 .. Digest'Last) & "  file.txt");
      begin
         AUnit.Assertions.Assert
           (Text_Mode.Valid
            and then Text_Mode.Name_First = 67
            and then Binary_Mode.Valid
            and then Binary_Mode.Name_First = 67
            and then not Empty_Name.Valid
            and then not Bad_Digest.Valid
            and then Posix_Tools.Text.Checksum_Lines.Lower_Hex (Digest)
              = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
            "SHA256 checksum line fields");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Character'Val (9))
         and then not Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Character'Val (10)),
         "POSIX blank excludes LF");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_POSIX_Space (Character'Val (13))
         and then not Posix_Tools.Text.Byte_Classes.Is_POSIX_Space ('A'),
         "POSIX space range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_Sort_Dictionary_Character ('A')
         and then Posix_Tools.Text.Byte_Classes.Is_Sort_Dictionary_Character (' ')
         and then not Posix_Tools.Text.Byte_Classes.Is_Sort_Dictionary_Character ('_'),
         "sort dictionary character class");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_Cut_List_Separator (',')
         and then Posix_Tools.Text.Byte_Classes.Is_Cut_List_Separator (' ')
         and then Posix_Tools.Text.Byte_Classes.Is_Cut_List_Separator (Character'Val (9))
         and then not Posix_Tools.Text.Byte_Classes.Is_Cut_List_Separator (';'),
         "cut list separator class");
      declare
         Single : constant Posix_Tools.Text.Cut_Fields.Parsed_Range :=
           Posix_Tools.Text.Cut_Fields.Parse_Range_Item ("3", 1);
         Closed : constant Posix_Tools.Text.Cut_Fields.Parsed_Range :=
           Posix_Tools.Text.Cut_Fields.Parse_Range_Item ("2-4,6", 1);
         Open_Start : constant Posix_Tools.Text.Cut_Fields.Parsed_Range :=
           Posix_Tools.Text.Cut_Fields.Parse_Range_Item ("-5", 1);
         Open_End : constant Posix_Tools.Text.Cut_Fields.Parsed_Range :=
           Posix_Tools.Text.Cut_Fields.Parse_Range_Item ("3-", 1);
         Descending : constant Posix_Tools.Text.Cut_Fields.Parsed_Range :=
           Posix_Tools.Text.Cut_Fields.Parse_Range_Item ("4-2", 1);
         Valid_List : constant Boolean :=
           Posix_Tools.Text.Cut_Fields.Parse_List ("1-3,5 7-");
         Empty_List : constant Boolean := Posix_Tools.Text.Cut_Fields.Parse_List ("");
         Trailing_Separator : constant Boolean :=
           Posix_Tools.Text.Cut_Fields.Parse_List ("1,");
      begin
         AUnit.Assertions.Assert
           (Single.Valid
            and then Single.Item.First = 3
            and then Single.Item.Last = 3
            and then Single.Next = 0
            and then Closed.Valid
            and then Closed.Item.First = 2
            and then Closed.Item.Last = 4
            and then Closed.Next = 4
            and then Open_Start.Valid
            and then Open_Start.Item.First = 1
            and then Open_Start.Item.Last = 5
            and then Open_Start.Next = 0
            and then Open_End.Valid
            and then Open_End.Item.First = 3
            and then Open_End.Item.Last = 0
            and then Open_End.Next = 0
            and then not Descending.Valid
            and then Posix_Tools.Text.Cut_Fields.Contains_Position (Closed.Item, 3)
            and then not Posix_Tools.Text.Cut_Fields.Contains_Position (Closed.Item, 5)
            and then Posix_Tools.Text.Cut_Fields.Contains_Position (Open_End.Item, 20),
            "cut range field parsing");
         AUnit.Assertions.Assert (Valid_List, "cut range list accepts mixed separators");
         AUnit.Assertions.Assert (not Empty_List, "cut range list rejects empty input");
         AUnit.Assertions.Assert
           (not Trailing_Separator, "cut range list rejects trailing separator");
      end;
      declare
         use type Posix_Tools.Text.DD_Conversions.Case_Conversion_Kind;
         use type Posix_Tools.Text.DD_Conversions.Block_Conversion_Kind;
         use type Posix_Tools.Text.DD_Conversions.Character_Set_Conversion_Kind;

         Parsed : constant Posix_Tools.Text.DD_Conversions.Parsed_Conversions :=
           Posix_Tools.Text.DD_Conversions.Parse_Conversions
             ("ucase,swab,sync,notrunc,noerror,block,ibm");
         Empty : constant Posix_Tools.Text.DD_Conversions.Parsed_Conversions :=
           Posix_Tools.Text.DD_Conversions.Parse_Conversions ("");
         Double_Comma : constant Posix_Tools.Text.DD_Conversions.Parsed_Conversions :=
           Posix_Tools.Text.DD_Conversions.Parse_Conversions ("sync,,swab");
      begin
         AUnit.Assertions.Assert
           (Parsed.Valid
            and then Parsed.Case_Conversion =
              Posix_Tools.Text.DD_Conversions.Uppercase_Conversion
            and then Parsed.Block_Conversion =
              Posix_Tools.Text.DD_Conversions.Block_Conversion
            and then Parsed.Character_Set_Conversion =
              Posix_Tools.Text.DD_Conversions.To_Ebcdic_Conversion
            and then Parsed.Swap_Adjacent_Bytes
            and then Parsed.Sync_Conversion
            and then Parsed.No_Truncate_Output
            and then Parsed.Continue_After_Read_Error
            and then not Empty.Valid
            and then not Double_Comma.Valid,
            "dd conversion parsing checks");
      end;
      declare
         use type Posix_Tools.Numbers.Count;

         Uppercase_Settings : constant Posix_Tools.Text.DD_Conversion_Engine.Conversion_Settings :=
           (Case_Conversion => Posix_Tools.Text.DD_Conversions.Uppercase_Conversion,
            others => <>);
         Swap_Settings : constant Posix_Tools.Text.DD_Conversion_Engine.Conversion_Settings :=
           (Swap_Adjacent_Bytes => True,
            others => <>);
         Block_Settings : constant Posix_Tools.Text.DD_Conversion_Engine.Conversion_Settings :=
           (Conversion_Block_Size => 4,
            Block_Conversion => Posix_Tools.Text.DD_Conversions.Block_Conversion,
            others => <>);
         Uppercase : constant Posix_Tools.Text.DD_Conversion_Engine.Conversion_Result :=
           Posix_Tools.Text.DD_Conversion_Engine.Apply ("abZ 12", Uppercase_Settings);
         Swapped : constant Posix_Tools.Text.DD_Conversion_Engine.Conversion_Result :=
           Posix_Tools.Text.DD_Conversion_Engine.Apply ("abcde", Swap_Settings);
         Blocked : constant Posix_Tools.Text.DD_Conversion_Engine.Conversion_Result :=
           Posix_Tools.Text.DD_Conversion_Engine.Apply
             ("a" & Character'Val (10) & "bcdef" & Character'Val (10) & "xy",
              Block_Settings);
      begin
         AUnit.Assertions.Assert
           (Ada.Strings.Unbounded.To_String (Uppercase.Output) = "ABZ 12"
            and then Uppercase.Truncated_Records = 0
            and then Ada.Strings.Unbounded.To_String (Swapped.Output) = "badce"
            and then Swapped.Truncated_Records = 0
            and then Ada.Strings.Unbounded.To_String (Blocked.Output) = "a   bcdexy  "
            and then Blocked.Truncated_Records = 1,
            "dd conversion engine applies byte conversions");
      end;
      declare
         use type Posix_Tools.Numbers.Count;
         use type Posix_Tools.Text.DD_Conversions.Block_Conversion_Kind;
         use type Posix_Tools.Text.DD_Conversions.Case_Conversion_Kind;

         Options : Posix_Tools.Text.DD_Operands.Settings;
         Error   : Ada.Strings.Unbounded.Unbounded_String;
         Parsed  : constant Boolean :=
           Posix_Tools.Text.DD_Operands.Parse_Argument ("if=input.bin", Options, Error)
           and then Posix_Tools.Text.DD_Operands.Parse_Argument ("of=out.bin", Options, Error)
           and then Posix_Tools.Text.DD_Operands.Parse_Argument ("bs=1024", Options, Error)
           and then Posix_Tools.Text.DD_Operands.Parse_Argument ("count=3", Options, Error)
           and then Posix_Tools.Text.DD_Operands.Parse_Argument ("skip=2", Options, Error)
           and then Posix_Tools.Text.DD_Operands.Parse_Argument ("seek=4", Options, Error)
           and then Posix_Tools.Text.DD_Operands.Parse_Argument ("cbs=8", Options, Error)
           and then Posix_Tools.Text.DD_Operands.Parse_Argument
             ("conv=ucase,block,notrunc,noerror", Options, Error)
           and then Posix_Tools.Text.DD_Operands.Validate (Options, Error);
      begin
         AUnit.Assertions.Assert
           (Parsed
            and then Ada.Strings.Unbounded.To_String (Options.Input) = "input.bin"
            and then Ada.Strings.Unbounded.To_String (Options.Output) = "out.bin"
            and then Options.Input_Block_Size = 1024
            and then Options.Output_Block_Size = 1024
            and then Options.Conversion_Settings.Input_Block_Size = 1024
            and then Options.Conversion_Settings.Conversion_Block_Size = 8
            and then Options.Count = 3
            and then Options.Skip_Blocks = 2
            and then Options.Seek_Blocks = 4
            and then Options.Conversion_Settings.Case_Conversion =
              Posix_Tools.Text.DD_Conversions.Uppercase_Conversion
            and then Options.Conversion_Settings.Block_Conversion =
              Posix_Tools.Text.DD_Conversions.Block_Conversion
            and then Options.No_Truncate_Output
            and then Options.Continue_After_Read_Error,
            "dd operand parser accepts core operands");
      end;
      declare
         Bad_Count : Posix_Tools.Text.DD_Operands.Settings;
         Missing_Cbs : Posix_Tools.Text.DD_Operands.Settings;
         Error : Ada.Strings.Unbounded.Unbounded_String;
         Empty_Count_Rejected : constant Boolean :=
           not Posix_Tools.Text.DD_Operands.Parse_Argument ("count=", Bad_Count, Error);
         Empty_Count_Message : constant String := Ada.Strings.Unbounded.To_String (Error);
         Block_Parsed : constant Boolean :=
           Posix_Tools.Text.DD_Operands.Parse_Argument ("conv=block", Missing_Cbs, Error);
         Missing_Cbs_Rejected : constant Boolean :=
           not Posix_Tools.Text.DD_Operands.Validate (Missing_Cbs, Error);
      begin
         AUnit.Assertions.Assert
           (Empty_Count_Rejected
            and then Empty_Count_Message = "invalid count 'count='"
            and then Block_Parsed
            and then Missing_Cbs_Rejected
            and then Ada.Strings.Unbounded.To_String (Error) = "invalid block size 'cbs'",
            "dd operand parser rejects invalid operands");
      end;
      declare
         use type Posix_Tools.Numbers.Count;
         use type Posix_Tools.Text.DD_Blocks.Transfer_Plan_Status;

         Empty_Counts : constant Posix_Tools.Text.DD_Blocks.Record_Counts :=
           Posix_Tools.Text.DD_Blocks.Counts_For (0, 512);
         Exact_Counts : constant Posix_Tools.Text.DD_Blocks.Record_Counts :=
           Posix_Tools.Text.DD_Blocks.Counts_For (1024, 512);
         Partial_Counts : constant Posix_Tools.Text.DD_Blocks.Record_Counts :=
           Posix_Tools.Text.DD_Blocks.Counts_For (1025, 512);
         Planned : constant Posix_Tools.Text.DD_Blocks.Transfer_Plan :=
           Posix_Tools.Text.DD_Blocks.Transfer_Slice
             (Input_Length      => 10,
              Count             => 2,
              Input_Block_Size  => 3,
              Output_Block_Size => 4,
              Skip_Blocks       => 1,
              Seek_Blocks       => 2);
         Skipped_Empty : constant Posix_Tools.Text.DD_Blocks.Transfer_Plan :=
           Posix_Tools.Text.DD_Blocks.Transfer_Slice
             (Input_Length      => 3,
              Count             => Posix_Tools.Numbers.Count'Last,
              Input_Block_Size  => 3,
              Output_Block_Size => 1,
              Skip_Blocks       => 1,
              Seek_Blocks       => 0);
         Count_Overflow : constant Posix_Tools.Text.DD_Blocks.Transfer_Plan :=
           Posix_Tools.Text.DD_Blocks.Transfer_Slice
             (Input_Length      => 3,
              Count             => Posix_Tools.Numbers.Count'Last / 2 + 1,
              Input_Block_Size  => 2,
              Output_Block_Size => 1,
              Skip_Blocks       => 0,
              Seek_Blocks       => 0);
         Prefix_Overflow : constant Posix_Tools.Text.DD_Blocks.Transfer_Plan :=
           Posix_Tools.Text.DD_Blocks.Transfer_Slice
             (Input_Length      => 3,
              Count             => 1,
              Input_Block_Size  => 1,
              Output_Block_Size => Posix_Tools.Numbers.Count (Natural'Last),
              Skip_Blocks       => 0,
              Seek_Blocks       => 2);
      begin
         AUnit.Assertions.Assert
           (Empty_Counts.Full = 0
            and then Empty_Counts.Partial = 0
            and then Exact_Counts.Full = 2
            and then Exact_Counts.Partial = 0
            and then Partial_Counts.Full = 2
            and then Partial_Counts.Partial = 1
            and then Posix_Tools.Text.DD_Blocks.Selected_Input ("abcdef", 2, 2) = "abcd"
            and then Posix_Tools.Text.DD_Blocks.Selected_Input ("abcdef", 2, 0) = ""
            and then Posix_Tools.Text.DD_Blocks.Offset_Overflows
              (Posix_Tools.Numbers.Count'Last, 2)
            and then not Posix_Tools.Text.DD_Blocks.Offset_Overflows (3, 2)
            and then Planned.Status = Posix_Tools.Text.DD_Blocks.Valid_Transfer
            and then Planned.Start_Index = 4
            and then Planned.Last_Index = 9
            and then Planned.Prefix_Count = 8
            and then Skipped_Empty.Status = Posix_Tools.Text.DD_Blocks.Valid_Transfer
            and then Skipped_Empty.Start_Index = 1
            and then Skipped_Empty.Last_Index = 0
            and then Count_Overflow.Status = Posix_Tools.Text.DD_Blocks.Count_Overflow
            and then Prefix_Overflow.Status = Posix_Tools.Text.DD_Blocks.Offset_Overflow,
            "dd block selection and transfer planning");
      end;
      declare
         use type Posix_Tools.Text.Duration_Fields.Duration_Unit;

         Seconds : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Field :=
           Posix_Tools.Text.Duration_Fields.Parse_Field ("1.5s");
         Minutes : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Field :=
           Posix_Tools.Text.Duration_Fields.Parse_Field (".25m");
         No_Suffix : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Field :=
           Posix_Tools.Text.Duration_Fields.Parse_Field ("10");
         Invalid_Dot : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Field :=
           Posix_Tools.Text.Duration_Fields.Parse_Field ("1.2.3");
         Invalid_Suffix : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Field :=
           Posix_Tools.Text.Duration_Fields.Parse_Field ("h");
         Negative : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Field :=
           Posix_Tools.Text.Duration_Fields.Parse_Field ("-1");
         Seconds_Ms : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Milliseconds :=
           Posix_Tools.Text.Duration_Fields.Parse_Milliseconds ("1.5s");
         Minutes_Ms : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Milliseconds :=
           Posix_Tools.Text.Duration_Fields.Parse_Milliseconds (".25m");
         Rounded_Ms : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Milliseconds :=
           Posix_Tools.Text.Duration_Fields.Parse_Milliseconds ("0.0015s");
         Invalid_Ms : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Milliseconds :=
           Posix_Tools.Text.Duration_Fields.Parse_Milliseconds ("-1");
      begin
         AUnit.Assertions.Assert
           (Seconds.Valid
            and then Seconds.Last_Index = 3
            and then Seconds.Dot_Index = 2
            and then Seconds.Unit = Posix_Tools.Text.Duration_Fields.Seconds
            and then Minutes.Valid
            and then Minutes.Last_Index = 3
            and then Minutes.Dot_Index = 1
            and then Minutes.Unit = Posix_Tools.Text.Duration_Fields.Minutes
            and then No_Suffix.Valid
            and then No_Suffix.Last_Index = 2
            and then No_Suffix.Dot_Index = 0
            and then No_Suffix.Unit = Posix_Tools.Text.Duration_Fields.Seconds
            and then not Invalid_Dot.Valid
            and then not Invalid_Suffix.Valid
            and then not Negative.Valid
            and then Seconds_Ms.Valid
            and then Seconds_Ms.Value = 1_500
            and then Minutes_Ms.Valid
            and then Minutes_Ms.Value = 15_000
            and then Rounded_Ms.Valid
            and then Rounded_Ms.Value = 2
            and then not Invalid_Ms.Valid,
            "duration field parsing checks");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_Portable_Filename_Character ('A')
         and then Posix_Tools.Text.Byte_Classes.Is_Portable_Filename_Character ('9')
         and then Posix_Tools.Text.Byte_Classes.Is_Portable_Filename_Character ('_')
         and then not Posix_Tools.Text.Byte_Classes.Is_Portable_Filename_Character ('/'),
         "portable filename character class");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_File_Text_Byte ('~')
         and then Posix_Tools.Text.Byte_Classes.Is_File_Text_Byte (Character'Val (9))
         and then Posix_Tools.Text.Byte_Classes.Is_File_Text_Byte (Character'Val (12))
         and then not Posix_Tools.Text.Byte_Classes.Is_File_Text_Byte (Character'Val (0))
         and then not Posix_Tools.Text.Byte_Classes.Is_File_Text_Byte (Character'Val (127)),
         "file text byte class");
      declare
         Valid_List : constant Posix_Tools.Text.Tab_Stops.Parsed_Stop_List :=
           Posix_Tools.Text.Tab_Stops.Parse_List ("4,8,16");
         Duplicate : constant Posix_Tools.Text.Tab_Stops.Parsed_Stop_List :=
           Posix_Tools.Text.Tab_Stops.Parse_List ("4,8,8");
         Trailing : constant Posix_Tools.Text.Tab_Stops.Parsed_Stop_List :=
           Posix_Tools.Text.Tab_Stops.Parse_List ("4,");
         Stop : constant Posix_Tools.Text.Tab_Stops.Parsed_Stop :=
           Posix_Tools.Text.Tab_Stops.Parse_Stop ("12", 8);
         Too_Small : constant Posix_Tools.Text.Tab_Stops.Parsed_Stop :=
           Posix_Tools.Text.Tab_Stops.Parse_Stop ("8", 8);
      begin
         AUnit.Assertions.Assert
           (Valid_List.Valid
            and then Valid_List.Last_Stop = 16
            and then not Duplicate.Valid
            and then not Trailing.Valid
            and then Stop.Valid
            and then Stop.Value = 12
            and then not Too_Small.Valid,
            "tab stop list parsing checks");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Matching.Starts_With ("abcdef", "abc")
         and then Posix_Tools.Text.Matching.Starts_With ("abcdef", "")
         and then not Posix_Tools.Text.Matching.Starts_With ("ab", "abc"),
         "prefix matching");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Matching.Starts_With_At ("abcdef", "cde", 3)
         and then not Posix_Tools.Text.Matching.Starts_With_At ("abcdef", "cde", 4)
         and then not Posix_Tools.Text.Matching.Starts_With_At ("abcdef", "", 1),
         "indexed prefix matching");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Matching.Ends_With ("abcdef", "def")
         and then Posix_Tools.Text.Matching.Ends_With ("abcdef", "")
         and then not Posix_Tools.Text.Matching.Ends_With ("ab", "abc")
         and then not Posix_Tools.Text.Matching.Ends_With ("abcdef", "cde"),
         "suffix matching");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Matching.Contains ("abc", 'b')
         and then not Posix_Tools.Text.Matching.Contains ("abc", 'x')
         and then not Posix_Tools.Text.Matching.Contains ("", 'x'),
         "character membership matching");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Matching.Contains ("abcdef", "cde")
         and then Posix_Tools.Text.Matching.Contains ("abcdef", "")
         and then not Posix_Tools.Text.Matching.Contains ("abcdef", "cdf")
         and then not Posix_Tools.Text.Matching.Contains ("ab", "abc"),
         "substring matching");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range ("59", 0, 59)
         and then Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range ("000", 0, 0)
         and then Posix_Tools.Text.Decimal_Parsing.Is_Decimal_Text ("042")
         and then not Posix_Tools.Text.Decimal_Parsing.Is_Decimal_Text ("")
         and then not Posix_Tools.Text.Decimal_Parsing.Is_Decimal_Text ("4x")
         and then Posix_Tools.Text.Decimal_Parsing.Two_Digit_Value ("07") = 7
         and then Posix_Tools.Text.Decimal_Parsing.Two_Digit_Value ("42") = 42
         and then Posix_Tools.Text.Decimal_Parsing.Four_Digit_Value ("2026") = 2_026
         and then Posix_Tools.Text.Decimal_Parsing.Natural_Value ("123").Valid
         and then Posix_Tools.Text.Decimal_Parsing.Natural_Value ("123").Value = 123
         and then Posix_Tools.Text.Decimal_Parsing.Long_Long_Value ("-42").Valid
         and then Posix_Tools.Text.Decimal_Parsing.Long_Long_Value ("-42").Value = -42
         and then Posix_Tools.Text.Decimal_Parsing.Long_Long_Value ("+42").Valid
         and then Posix_Tools.Text.Decimal_Parsing.Long_Long_Value ("+42").Value = 42
         and then Posix_Tools.Text.Decimal_Parsing.Looks_Like_Negative_Number ("-1")
         and then Posix_Tools.Text.Decimal_Parsing.Looks_Like_Negative_Number ("-.5")
         and then not Posix_Tools.Text.Decimal_Parsing.Looks_Like_Negative_Number ("-x")
         and then not Posix_Tools.Text.Decimal_Parsing.Looks_Like_Negative_Number ("1")
         and then
           Posix_Tools.Text.Decimal_Parsing.Long_Long_Addition_Overflows
             (Long_Long_Integer'Last, 1)
         and then
           Posix_Tools.Text.Decimal_Parsing.Long_Long_Addition_Overflows
             (Long_Long_Integer'First, -1)
         and then
           not Posix_Tools.Text.Decimal_Parsing.Long_Long_Addition_Overflows
             (Long_Long_Integer'Last - 1, 1)
         and then
           not Posix_Tools.Text.Decimal_Parsing.Long_Long_Addition_Overflows
             (Long_Long_Integer'First + 1, -1)
         and then Posix_Tools.Text.Decimal_Parsing.Power_10 (0) = 1
         and then Posix_Tools.Text.Decimal_Parsing.Power_10 (3) = 1_000
         and then Posix_Tools.Text.Decimal_Parsing.Scale_By_Power_10 (12, 2).Valid
         and then Posix_Tools.Text.Decimal_Parsing.Scale_By_Power_10 (12, 2).Value = 1_200
         and then Posix_Tools.Text.Decimal_Parsing.Scale_By_Power_10 (-12, 2).Valid
         and then Posix_Tools.Text.Decimal_Parsing.Scale_By_Power_10 (-12, 2).Value = -1_200
         and then not Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range ("60", 0, 59)
         and then not Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range ("", 0, 59)
         and then not Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range ("5x", 0, 59)
         and then not Posix_Tools.Text.Decimal_Parsing.Long_Long_Value ("+").Valid
         and then not Posix_Tools.Text.Decimal_Parsing.Long_Long_Value ("1x").Valid
         and then
           not Posix_Tools.Text.Decimal_Parsing.Scale_By_Power_10
             (Long_Long_Integer'Last, 1).Valid
         and then
           not Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range
             ("999999999999999999999999999999999999999999", 0, Natural'Last),
         "decimal parsing range checks");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Base_Parsing.Natural_Value ("17", 8).Valid
         and then Posix_Tools.Text.Base_Parsing.Natural_Value ("17", 8).Value = 15
         and then Posix_Tools.Text.Base_Parsing.Natural_Value ("ff", 16).Valid
         and then Posix_Tools.Text.Base_Parsing.Natural_Value ("ff", 16).Value = 255
         and then Posix_Tools.Text.Base_Parsing.Natural_Value ("101", 2).Valid
         and then Posix_Tools.Text.Base_Parsing.Natural_Value ("101", 2).Value = 5
         and then Posix_Tools.Text.Base_Parsing.Scaled_Natural_Value ("10", 10, 512).Valid
         and then Posix_Tools.Text.Base_Parsing.Scaled_Natural_Value ("10", 10, 512).Value = 5_120
         and then not Posix_Tools.Text.Base_Parsing.Natural_Value ("8", 8).Valid
         and then not Posix_Tools.Text.Base_Parsing.Natural_Value ("", 10).Valid
         and then
           not Posix_Tools.Text.Base_Parsing.Natural_Value
             ("ffffffffffffffffffffffffffffffffffffffff", 16).Valid
         and then
           not Posix_Tools.Text.Base_Parsing.Scaled_Natural_Value
             ("999999999999999999999999999999999999999", 10, 1_024).Valid,
         "base parsing range checks");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Suffixes.Lowercase_Capacity (1) = 26
         and then Posix_Tools.Text.Suffixes.Lowercase_Capacity (2) = 676
         and then Posix_Tools.Text.Suffixes.Lowercase_Capacity (100) = Natural'Last
         and then Posix_Tools.Text.Suffixes.Lowercase_Image (0, 2) = "aa"
         and then Posix_Tools.Text.Suffixes.Lowercase_Image (25, 2) = "az"
         and then Posix_Tools.Text.Suffixes.Lowercase_Image (26, 2) = "ba",
         "lowercase suffix checks");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Logical_Paths.Usable_Logical_Path ("/")
         and then Posix_Tools.Text.Logical_Paths.Usable_Logical_Path ("/tmp//work")
         and then Posix_Tools.Text.Logical_Paths.Usable_Logical_Path ("/tmp/.../work")
         and then not Posix_Tools.Text.Logical_Paths.Usable_Logical_Path ("")
         and then not Posix_Tools.Text.Logical_Paths.Usable_Logical_Path ("relative")
         and then not Posix_Tools.Text.Logical_Paths.Usable_Logical_Path ("/tmp/./work")
         and then not Posix_Tools.Text.Logical_Paths.Usable_Logical_Path ("/tmp/../work"),
         "logical path validation checks");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Portable_Paths.Portable_Component ("portable_1.2")
         and then Posix_Tools.Text.Portable_Paths.Portable_Component ("")
         and then Posix_Tools.Text.Portable_Paths.Portable_Component ("a-b_C.9")
         and then not Posix_Tools.Text.Portable_Paths.Portable_Component ("bad@name")
         and then not Posix_Tools.Text.Portable_Paths.Portable_Component
           ("bad" & Character'Val (10)),
         "portable path component checks");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Test_Operators.Is_Unary_Operator ("-e")
         and then Posix_Tools.Text.Test_Operators.Is_Unary_Operator ("-x")
         and then not Posix_Tools.Text.Test_Operators.Is_Unary_Operator ("-a")
         and then not Posix_Tools.Text.Test_Operators.Is_Unary_Operator ("=")
         and then Posix_Tools.Text.Test_Operators.Is_Binary_Operator ("=")
         and then Posix_Tools.Text.Test_Operators.Is_Binary_Operator ("-le")
         and then not Posix_Tools.Text.Test_Operators.Is_Binary_Operator ("-x")
         and then not Posix_Tools.Text.Test_Operators.Is_Binary_Operator ("-a")
         and then Posix_Tools.Text.Test_Operators.Numeric_Comparison ("7", "-eq", "7")
         and then Posix_Tools.Text.Test_Operators.Numeric_Comparison ("7", "-gt", "-2")
         and then Posix_Tools.Text.Test_Operators.Numeric_Comparison ("-2", "-le", "-2")
         and then not Posix_Tools.Text.Test_Operators.Numeric_Comparison ("7", "-lt", "-2")
         and then not Posix_Tools.Text.Test_Operators.Numeric_Comparison ("x", "-eq", "0")
         and then not Posix_Tools.Text.Test_Operators.Numeric_Comparison ("1", "-x", "1"),
         "test operator classifier checks");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Hex_Digests.Is_SHA256_Digest
           ("e3b0c44298fc1c149afbf4c8996fb924"
            & "27ae41e4649b934ca495991b7852b855")
         and then Posix_Tools.Text.Hex_Digests.Is_SHA256_Digest
           ("E3B0C44298FC1C149AFBF4C8996FB924"
            & "27AE41E4649B934CA495991B7852B855")
         and then not Posix_Tools.Text.Hex_Digests.Is_SHA256_Digest
           ("e3b0c44298fc1c149afbf4c8996fb924"
            & "27ae41e4649b934ca495991b7852b85")
         and then not Posix_Tools.Text.Hex_Digests.Is_SHA256_Digest
           ("e3b0c44298fc1c149afbf4c8996fb924"
            & "27ae41e4649b934ca495991b7852b85x"),
         "SHA256 digest classifier checks");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Sort_Modifiers.Is_Key_Modifier ('b')
         and then Posix_Tools.Text.Sort_Modifiers.Is_Key_Modifier ('d')
         and then Posix_Tools.Text.Sort_Modifiers.Is_Key_Modifier ('f')
         and then Posix_Tools.Text.Sort_Modifiers.Is_Key_Modifier ('i')
         and then Posix_Tools.Text.Sort_Modifiers.Is_Key_Modifier ('n')
         and then Posix_Tools.Text.Sort_Modifiers.Is_Key_Modifier ('r')
         and then not Posix_Tools.Text.Sort_Modifiers.Is_Key_Modifier ('a')
         and then not Posix_Tools.Text.Sort_Modifiers.Is_Key_Modifier ('B'),
         "sort key modifier classifier checks");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Sort_Modifiers.Applies_Locale_Collation (False, False, False)
         and then not Posix_Tools.Text.Sort_Modifiers.Applies_Locale_Collation (True, False, False)
         and then not Posix_Tools.Text.Sort_Modifiers.Applies_Locale_Collation (False, True, False)
         and then not Posix_Tools.Text.Sort_Modifiers.Applies_Locale_Collation (False, False, True)
         and then not Posix_Tools.Text.Sort_Modifiers.Applies_Locale_Collation (True, True, True),
         "sort transformed key locale collation checks");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Sort_Numeric.Numeric_Field ("C", "  -001.230x") = "-001.230"
         and then Posix_Tools.Text.Sort_Numeric.Numeric_Field ("C", "no-number") = "0"
         and then Posix_Tools.Text.Sort_Numeric.Decimal_Compare ("1e3", "999") > 0
         and then Posix_Tools.Text.Sort_Numeric.Decimal_Compare ("1.20", "1.2") = 0
         and then Posix_Tools.Text.Sort_Numeric.Numeric_Compare ("C", " -2", " 10") < 0,
         "sort numeric field and comparison checks");
      declare
         Parsed_Field : constant Posix_Tools.Text.Sort_Modifiers.Parsed_Key_Number :=
           Posix_Tools.Text.Sort_Modifiers.Parse_Positive_Key_Number ("12.3f", 1, 5);
         Parsed_Char : constant Posix_Tools.Text.Sort_Modifiers.Parsed_Key_Number :=
           Posix_Tools.Text.Sort_Modifiers.Parse_Positive_Key_Number ("12.3f", 4, 5);
         Parsed_Zero : constant Posix_Tools.Text.Sort_Modifiers.Parsed_Key_Number :=
           Posix_Tools.Text.Sort_Modifiers.Parse_Positive_Key_Number ("0", 1, 1);
         Parsed_Empty : constant Posix_Tools.Text.Sort_Modifiers.Parsed_Key_Number :=
           Posix_Tools.Text.Sort_Modifiers.Parse_Positive_Key_Number ("12.3f", 6, 5);
      begin
         AUnit.Assertions.Assert
           (Parsed_Field.Valid
            and then Parsed_Field.Value = 12
            and then Parsed_Field.Last_Digit = 2
            and then Parsed_Char.Valid
            and then Parsed_Char.Value = 3
            and then Parsed_Char.Last_Digit = 4
            and then not Parsed_Zero.Valid
            and then Parsed_Zero.Value = 0
            and then not Parsed_Empty.Valid
            and then Parsed_Empty.Value = 0,
            "sort key positive number parsing checks");
      end;
      declare
         Parsed_Key : constant Posix_Tools.Text.Sort_Modifiers.Parsed_Key :=
           Posix_Tools.Text.Sort_Modifiers.Parse_Key ("2.3bf,4.5nr");
         Reversed_Field : constant Posix_Tools.Text.Sort_Modifiers.Parsed_Key :=
           Posix_Tools.Text.Sort_Modifiers.Parse_Key ("4,2");
         Reversed_Character : constant Posix_Tools.Text.Sort_Modifiers.Parsed_Key :=
           Posix_Tools.Text.Sort_Modifiers.Parse_Key ("2.5,2.3");
      begin
         AUnit.Assertions.Assert
           (Parsed_Key.Valid
            and then Parsed_Key.Field_Start = 2
            and then Parsed_Key.Character_Start = 3
            and then Parsed_Key.Field_End = 4
            and then Parsed_Key.Character_End = 5
            and then Parsed_Key.Ignore_Leading_Blanks
            and then Parsed_Key.Fold_Case
            and then Parsed_Key.Numeric_Sort
            and then Parsed_Key.Reverse_Order
            and then not Reversed_Field.Valid
            and then not Reversed_Character.Valid,
            "sort key full parsing checks");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Signal_Names.Known_Signal_Name ("HUP")
         = Posix_Tools.Text.Signal_Names.Hangup_Name
         and then Posix_Tools.Text.Signal_Names.Known_Signal_Name ("siginT")
         = Posix_Tools.Text.Signal_Names.Interrupt_Name
         and then Posix_Tools.Text.Signal_Names.Known_Signal_Name ("quit")
         = Posix_Tools.Text.Signal_Names.Quit_Name
         and then Posix_Tools.Text.Signal_Names.Known_Signal_Name ("SIGKILL")
         = Posix_Tools.Text.Signal_Names.Kill_Name
         and then Posix_Tools.Text.Signal_Names.Known_Signal_Name ("term")
         = Posix_Tools.Text.Signal_Names.Terminate_Name
         and then Posix_Tools.Text.Signal_Names.Known_Signal_Name ("stop")
         = Posix_Tools.Text.Signal_Names.Stop_Name
         and then Posix_Tools.Text.Signal_Names.Known_Signal_Name ("TSTP")
         = Posix_Tools.Text.Signal_Names.Terminal_Stop_Name
         and then Posix_Tools.Text.Signal_Names.Known_Signal_Name ("cont")
         = Posix_Tools.Text.Signal_Names.Continue_Name
         and then Posix_Tools.Text.Signal_Names.Known_Signal_Name ("pipe")
         = Posix_Tools.Text.Signal_Names.Pipe_Name
         and then Posix_Tools.Text.Signal_Names.Known_Signal_Name ("unknown")
         = Posix_Tools.Text.Signal_Names.Unknown_Signal_Name
         and then Posix_Tools.Text.Signal_Names.Is_SIG_Prefixed ("SIGTERM")
         and then Posix_Tools.Text.Signal_Names.Is_SIG_Prefixed ("sig15")
         and then not Posix_Tools.Text.Signal_Names.Is_SIG_Prefixed ("SI")
         and then not Posix_Tools.Text.Signal_Names.Is_SIG_Prefixed ("TERM"),
         "signal name classifier checks");
      declare
         Decoded : constant String :=
           Posix_Tools.Text.Paste_Delimiters.Decode_Delimiters ("a\nt\0\\x");
      begin
         AUnit.Assertions.Assert
           (Posix_Tools.Text.Paste_Delimiters.Decoded_Delimiter_Length
              ("a\nt\0\\x") = 6
            and then Decoded'Length = 6
            and then Decoded (1) = 'a'
            and then Decoded (2) = Character'Val (10)
            and then Decoded (3) = 't'
            and then Decoded (4) = Character'Val (0)
            and then Decoded (5) = '\'
            and then Decoded (6) = 'x'
            and then Posix_Tools.Text.Paste_Delimiters.Delimiter (Decoded, 1) = "a"
            and then Posix_Tools.Text.Paste_Delimiters.Delimiter (Decoded, 4) = ""
            and then Posix_Tools.Text.Paste_Delimiters.Delimiter ("", 1) = "",
            "paste delimiter decoding checks");
      end;
      declare
         Positive_Adjustment : constant Posix_Tools.Text.Nice_Fields.Parsed_Adjustment :=
           Posix_Tools.Text.Nice_Fields.Parse_Adjustment ("10");
         Negative_Adjustment : constant Posix_Tools.Text.Nice_Fields.Parsed_Adjustment :=
           Posix_Tools.Text.Nice_Fields.Parse_Adjustment ("-20");
         Too_Low : constant Posix_Tools.Text.Nice_Fields.Parsed_Adjustment :=
           Posix_Tools.Text.Nice_Fields.Parse_Adjustment ("-2147483648");
         Invalid : constant Posix_Tools.Text.Nice_Fields.Parsed_Adjustment :=
           Posix_Tools.Text.Nice_Fields.Parse_Adjustment ("+");
      begin
         AUnit.Assertions.Assert
           (Positive_Adjustment.Valid
            and then Positive_Adjustment.Value = 10
            and then Negative_Adjustment.Valid
            and then Negative_Adjustment.Value = -20
            and then not Too_Low.Valid
            and then Too_Low.Value = 0
            and then not Invalid.Valid
            and then Invalid.Value = 0,
            "nice adjustment parsing checks");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Xargs_Fields.Size_With_Item (0, 3) = 4
         and then Posix_Tools.Text.Xargs_Fields.Size_With_Item (4, 2) = 7
         and then Posix_Tools.Text.Xargs_Fields.Size_With_Item
           (Natural'Last - 1, 1) = Natural'Last
         and then Posix_Tools.Text.Xargs_Fields.Size_With_Item
           (0, Natural'Last) = Natural'Last,
         "xargs command size saturation checks");
      declare
         LF      : constant Character := Character'Val (10);
         Slash   : constant Character := Character'Val (16#5C#);
         Parsed  : constant Posix_Tools.Text.NL_Fields.Parsed_Long_Long :=
           Posix_Tools.Text.NL_Fields.Positive_Long_Value ("12");
         Invalid : constant Posix_Tools.Text.NL_Fields.Parsed_Long_Long :=
           Posix_Tools.Text.NL_Fields.Positive_Long_Value ("+12");
      begin
         AUnit.Assertions.Assert
           (Posix_Tools.Text.NL_Fields.Mode_For ("a") = Posix_Tools.Text.NL_Fields.All_Lines
            and then Posix_Tools.Text.NL_Fields.Mode_For ("t") =
              Posix_Tools.Text.NL_Fields.Nonempty_Lines
            and then Posix_Tools.Text.NL_Fields.Mode_For ("n") =
              Posix_Tools.Text.NL_Fields.No_Lines
            and then Posix_Tools.Text.NL_Fields.Mode_For ("x") =
              Posix_Tools.Text.NL_Fields.Unknown_Number_Mode
            and then Parsed.Valid
            and then Parsed.Value = 12
            and then not Invalid.Valid
            and then not Posix_Tools.Text.NL_Fields.Positive_Long_Value ("").Valid
            and then not Posix_Tools.Text.NL_Fields.Positive_Long_Value ("0").Valid
            and then not Posix_Tools.Text.NL_Fields.Positive_Long_Value ("-1").Valid
            and then Posix_Tools.Text.NL_Fields.Is_Empty_Line ("")
            and then Posix_Tools.Text.NL_Fields.Is_Empty_Line ("" & LF)
            and then not Posix_Tools.Text.NL_Fields.Is_Empty_Line ("x" & LF)
            and then
              Posix_Tools.Text.NL_Fields.Logical_Section_For
                ("" & Slash & ":" & Slash & ":" & Slash & ":", Slash, ':') =
              Posix_Tools.Text.NL_Fields.Header_Section
            and then
              Posix_Tools.Text.NL_Fields.Logical_Section_For
                ("" & Slash & ":" & Slash & ":" & LF, Slash, ':') =
              Posix_Tools.Text.NL_Fields.Body_Section
            and then
              Posix_Tools.Text.NL_Fields.Logical_Section_For
                ("" & Slash & ":" & LF, Slash, ':') =
              Posix_Tools.Text.NL_Fields.Footer_Section
            and then
              Posix_Tools.Text.NL_Fields.Logical_Section_For
                ("" & Slash & ":" & "x", Slash, ':') =
              Posix_Tools.Text.NL_Fields.No_Section,
            "nl field classifier checks");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.File_Modes.Four_Digit_Octal_Image (0) = "0000"
         and then Posix_Tools.Text.File_Modes.Four_Digit_Octal_Image (8#755#) = "0755"
         and then Posix_Tools.Text.File_Modes.Four_Digit_Octal_Image (8#17777#) = "7777"
         and then Posix_Tools.Text.File_Modes.Four_Digit_Octal_Image (8#10000#) = "0000"
         and then Posix_Tools.Text.File_Modes.Has_Mode_Bit (8#400#, 8#400#)
         and then not Posix_Tools.Text.File_Modes.Has_Mode_Bit (8#200#, 8#400#)
         and then Posix_Tools.Text.File_Modes.Has_Any_Mode_Bit (8#640#, 8#040#)
         and then not Posix_Tools.Text.File_Modes.Has_Any_Mode_Bit (8#600#, 8#007#)
         and then Posix_Tools.Text.File_Modes.Has_All_Mode_Bits (8#640#, 8#640#)
         and then not Posix_Tools.Text.File_Modes.Has_All_Mode_Bits (8#600#, 8#640#)
         and then Posix_Tools.Text.File_Modes.Set_Mode_Bit (8#600#, 8#040#) = 8#640#
         and then Posix_Tools.Text.File_Modes.Set_Mode_Bit (8#640#, 8#040#) = 8#640#
         and then Posix_Tools.Text.File_Modes.Set_Mode_Mask (8#600#, 8#047#) = 8#647#
         and then Posix_Tools.Text.File_Modes.Clear_Mode_Bit (8#640#, 8#040#) = 8#600#
         and then Posix_Tools.Text.File_Modes.Clear_Mode_Bit (8#600#, 8#040#) = 8#600#
         and then Posix_Tools.Text.File_Modes.Clear_Mode_Mask (8#675#, 8#075#) = 8#600#
         and then Posix_Tools.Text.File_Modes.Symbolic_Who_Mask (0, 'u') = 8#4700#
         and then Posix_Tools.Text.File_Modes.Symbolic_Who_Mask (8#4700#, 'g') = 8#6770#
         and then Posix_Tools.Text.File_Modes.Symbolic_Who_Mask (0, 'o') = 8#1007#
         and then Posix_Tools.Text.File_Modes.Symbolic_Who_Mask (8#600#, 'a') = 8#7777#
         and then Posix_Tools.Text.File_Modes.Symbolic_Who_Mask (8#600#, 'x') = 8#600#
         and then Posix_Tools.Text.File_Modes.Permission_Matches (8#640#, 8#640#, False)
         and then not Posix_Tools.Text.File_Modes.Permission_Matches (8#600#, 8#640#, False)
         and then Posix_Tools.Text.File_Modes.Permission_Matches (8#640#, 8#640#, True)
         and then not Posix_Tools.Text.File_Modes.Permission_Matches (8#600#, 8#640#, True),
         "file mode image checks");
      declare
         Read_Bits : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits_Result :=
             Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits (8#7777#, 0, 'r');
         Write_Bits : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits_Result :=
             Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits (8#7777#, 0, 'w');
         Exec_Bits : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits_Result :=
             Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits (8#7777#, 0, 'x');
         Special_Bits : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits_Result :=
             Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits (8#7777#, 0, 's');
         Copy_User_Bits : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits_Result :=
             Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits
               (8#0777#, 8#640#, 'u');
         Copy_Group_Bits : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits_Result :=
             Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits
               (8#0777#, 8#070#, 'g');
         Copy_Other_Bits : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits_Result :=
             Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits
               (8#0777#, 8#007#, 'o');
         Invalid_Bits : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits_Result :=
             Posix_Tools.Text.File_Modes.Symbolic_Permission_Bits (8#7777#, 0, 'z');
      begin
         AUnit.Assertions.Assert
           (Read_Bits.Valid
            and then Read_Bits.Bits = 8#444#
            and then Write_Bits.Valid
            and then Write_Bits.Bits = 8#222#
            and then Exec_Bits.Valid
            and then Exec_Bits.Bits = 8#111#
            and then Special_Bits.Valid
            and then Special_Bits.Bits = 8#6000#
            and then Copy_User_Bits.Valid
            and then Copy_User_Bits.Bits = 8#666#
            and then Copy_Group_Bits.Valid
            and then Copy_Group_Bits.Bits = 8#777#
            and then Copy_Other_Bits.Valid
            and then Copy_Other_Bits.Bits = 8#777#
            and then not Invalid_Bits.Valid
            and then Invalid_Bits.Bits = 0,
            "symbolic permission bit checks");
      end;
      declare
         Added : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Operation_Result :=
             Posix_Tools.Text.File_Modes.Apply_Symbolic_Permission_Operation
               (8#600#, 8#7777#, 8#044#, '+');
         Removed : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Operation_Result :=
             Posix_Tools.Text.File_Modes.Apply_Symbolic_Permission_Operation
               (8#675#, 8#7777#, 8#075#, '-');
         Assigned : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Operation_Result :=
             Posix_Tools.Text.File_Modes.Apply_Symbolic_Permission_Operation
               (8#675#, 8#0770#, 8#0640#, '=');
         Invalid_Operation : constant
           Posix_Tools.Text.File_Modes.Symbolic_Permission_Operation_Result :=
             Posix_Tools.Text.File_Modes.Apply_Symbolic_Permission_Operation
               (8#675#, 8#7777#, 8#075#, 'x');
      begin
         AUnit.Assertions.Assert
           (Added.Valid
            and then Added.Mode = 8#644#
            and then Removed.Valid
            and then Removed.Mode = 8#600#
            and then Assigned.Valid
            and then Assigned.Mode = 8#645#
            and then not Invalid_Operation.Valid
            and then Invalid_Operation.Mode = 8#675#,
            "symbolic permission operation checks");
      end;
      declare
         Assign_Mode : constant Posix_Tools.Text.File_Modes.Symbolic_Mode_Result :=
           Posix_Tools.Text.File_Modes.Apply_Symbolic_Mode ("u=rw,go=r", 0);
         Add_Mode : constant Posix_Tools.Text.File_Modes.Symbolic_Mode_Result :=
           Posix_Tools.Text.File_Modes.Apply_Symbolic_Mode ("g+r,o+r", 8#600#);
         Copy_Mode : constant Posix_Tools.Text.File_Modes.Symbolic_Mode_Result :=
           Posix_Tools.Text.File_Modes.Apply_Symbolic_Mode ("u+x,g=u,o=g", 8#444#);
         Empty_Assign : constant Posix_Tools.Text.File_Modes.Symbolic_Mode_Result :=
           Posix_Tools.Text.File_Modes.Apply_Symbolic_Mode ("a=,u+rwx,go+rx", 0);
         Invalid_Mode : constant Posix_Tools.Text.File_Modes.Symbolic_Mode_Result :=
           Posix_Tools.Text.File_Modes.Apply_Symbolic_Mode ("u+", 0);
      begin
         AUnit.Assertions.Assert
           (Assign_Mode.Valid
            and then Assign_Mode.Mode = 8#644#
            and then Add_Mode.Valid
            and then Add_Mode.Mode = 8#644#
            and then Copy_Mode.Valid
            and then Copy_Mode.Mode = 8#555#
            and then Empty_Assign.Valid
            and then Empty_Assign.Mode = 8#755#
            and then not Invalid_Mode.Valid
            and then Invalid_Mode.Mode = 0,
            "symbolic mode application checks");
      end;
      declare
         Parsed_Octal : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
           Posix_Tools.Text.File_Modes.Parse_Permission_Mode ("0640");
         Parsed_All : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
           Posix_Tools.Text.File_Modes.Parse_Permission_Mode ("-0640");
         Parsed_Leading_Zeros : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
           Posix_Tools.Text.File_Modes.Parse_Permission_Mode ("00000");
         Parsed_Too_Large : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
           Posix_Tools.Text.File_Modes.Parse_Permission_Mode ("10000");
         Parsed_Symbolic : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
           Posix_Tools.Text.File_Modes.Parse_Permission_Mode ("u+r");
         Parsed_Empty : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
           Posix_Tools.Text.File_Modes.Parse_Permission_Mode ("");
         Parsed_Find_Symbolic : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
           Posix_Tools.Text.File_Modes.Parse_Find_Permission_Mode ("u+r,g-w");
         Parsed_Find_All_Symbolic : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
           Posix_Tools.Text.File_Modes.Parse_Find_Permission_Mode ("-u+r");
         Parsed_Find_Invalid : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
           Posix_Tools.Text.File_Modes.Parse_Find_Permission_Mode ("u+");
      begin
         AUnit.Assertions.Assert
           (Parsed_Octal.Status = Posix_Tools.Text.File_Modes.Octal_Permission_Mode
            and then Parsed_Octal.Mode = 8#640#
            and then not Parsed_Octal.Match_All
            and then Parsed_All.Status = Posix_Tools.Text.File_Modes.Octal_Permission_Mode
            and then Parsed_All.Mode = 8#640#
            and then Parsed_All.Match_All
            and then Parsed_Leading_Zeros.Status =
              Posix_Tools.Text.File_Modes.Octal_Permission_Mode
            and then Parsed_Leading_Zeros.Mode = 0
            and then Parsed_Too_Large.Status =
              Posix_Tools.Text.File_Modes.Invalid_Permission_Mode
            and then Parsed_Symbolic.Status =
              Posix_Tools.Text.File_Modes.Symbolic_Permission_Mode
            and then Parsed_Symbolic.Mode = 0
            and then Parsed_Empty.Status =
              Posix_Tools.Text.File_Modes.Invalid_Permission_Mode
            and then Parsed_Find_Symbolic.Status =
              Posix_Tools.Text.File_Modes.Symbolic_Permission_Mode
            and then Parsed_Find_Symbolic.Mode = 8#400#
            and then not Parsed_Find_Symbolic.Match_All
            and then Parsed_Find_All_Symbolic.Status =
              Posix_Tools.Text.File_Modes.Symbolic_Permission_Mode
            and then Parsed_Find_All_Symbolic.Mode = 8#400#
            and then Parsed_Find_All_Symbolic.Match_All
            and then Parsed_Find_Invalid.Status =
              Posix_Tools.Text.File_Modes.Invalid_Permission_Mode
            and then Parsed_Find_Invalid.Mode = 0,
            "find permission mode parsing checks");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Find_Expressions.Count_Matches
           (10, 10, Posix_Tools.Text.Find_Expressions.Exact_Count)
         and then Posix_Tools.Text.Find_Expressions.Count_Matches
           (11, 10, Posix_Tools.Text.Find_Expressions.Greater_Than_Count)
         and then Posix_Tools.Text.Find_Expressions.Count_Matches
           (9, 10, Posix_Tools.Text.Find_Expressions.Less_Than_Count)
         and then not Posix_Tools.Text.Find_Expressions.Count_Matches
           (10, 10, Posix_Tools.Text.Find_Expressions.Less_Than_Count),
         "find count relation checks");
      declare
         Parsed_Exact : constant Posix_Tools.Text.Find_Expressions.Parsed_Find_Count :=
           Posix_Tools.Text.Find_Expressions.Parse_Find_Count ("12");
         Parsed_Greater_Bytes : constant Posix_Tools.Text.Find_Expressions.Parsed_Find_Count :=
           Posix_Tools.Text.Find_Expressions.Parse_Find_Count ("+12c");
         Parsed_Less : constant Posix_Tools.Text.Find_Expressions.Parsed_Find_Count :=
           Posix_Tools.Text.Find_Expressions.Parse_Find_Count ("-3");
         Parsed_Empty : constant Posix_Tools.Text.Find_Expressions.Parsed_Find_Count :=
           Posix_Tools.Text.Find_Expressions.Parse_Find_Count ("");
         Parsed_Double_Sign : constant Posix_Tools.Text.Find_Expressions.Parsed_Find_Count :=
           Posix_Tools.Text.Find_Expressions.Parse_Find_Count ("++3");
         Parsed_Bytes_Only : constant Posix_Tools.Text.Find_Expressions.Parsed_Find_Count :=
           Posix_Tools.Text.Find_Expressions.Parse_Find_Count ("c");
      begin
         AUnit.Assertions.Assert
           (Parsed_Exact.Valid
            and then Parsed_Exact.Count = 12
            and then Parsed_Exact.Relation = Posix_Tools.Text.Find_Expressions.Exact_Count
            and then not Parsed_Exact.Bytes
            and then Parsed_Greater_Bytes.Valid
            and then Parsed_Greater_Bytes.Count = 12
            and then Parsed_Greater_Bytes.Relation =
              Posix_Tools.Text.Find_Expressions.Greater_Than_Count
            and then Parsed_Greater_Bytes.Bytes
            and then Parsed_Less.Valid
            and then Parsed_Less.Count = 3
            and then Parsed_Less.Relation = Posix_Tools.Text.Find_Expressions.Less_Than_Count
            and then not Parsed_Empty.Valid
            and then not Parsed_Double_Sign.Valid
            and then not Parsed_Bytes_Only.Valid,
            "find count parsing checks");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Find_Expressions.Age_Matches
           (Duration (90), Duration (60), Duration (120),
            Posix_Tools.Text.Find_Expressions.Exact_Count)
         and then Posix_Tools.Text.Find_Expressions.Age_Matches
           (Duration (121), Duration (120), 0.0,
            Posix_Tools.Text.Find_Expressions.Greater_Than_Count)
         and then Posix_Tools.Text.Find_Expressions.Age_Matches
           (Duration (59), 0.0, Duration (60),
            Posix_Tools.Text.Find_Expressions.Less_Than_Count)
         and then not Posix_Tools.Text.Find_Expressions.Age_Matches
           (Duration (120), Duration (60), Duration (120),
            Posix_Tools.Text.Find_Expressions.Exact_Count),
         "find age relation checks");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Find_Expressions.Ownership_Matches
           (True, True, 10, 20, 10)
         and then Posix_Tools.Text.Find_Expressions.Ownership_Matches
           (True, False, 10, 20, 20)
         and then not Posix_Tools.Text.Find_Expressions.Ownership_Matches
           (False, True, 10, 20, 10)
         and then not Posix_Tools.Text.Find_Expressions.Ownership_Matches
           (True, False, 10, 20, 10)
         and then Posix_Tools.Text.Find_Expressions.Missing_Owner_Name_Matches
           (True, "")
         and then not Posix_Tools.Text.Find_Expressions.Missing_Owner_Name_Matches
           (False, "")
         and then not Posix_Tools.Text.Find_Expressions.Missing_Owner_Name_Matches
           (True, "root"),
         "find ownership predicate checks");
      declare
         Parsed_D : constant Posix_Tools.Text.Find_Expressions.Parsed_Type_Filter :=
           Posix_Tools.Text.Find_Expressions.Parse_Type_Filter ("d");
         Parsed_S : constant Posix_Tools.Text.Find_Expressions.Parsed_Type_Filter :=
           Posix_Tools.Text.Find_Expressions.Parse_Type_Filter ("s");
         Parsed_Invalid : constant Posix_Tools.Text.Find_Expressions.Parsed_Type_Filter :=
           Posix_Tools.Text.Find_Expressions.Parse_Type_Filter ("x");
      begin
         AUnit.Assertions.Assert
           (Parsed_D.Valid
            and then Parsed_D.Filter = Posix_Tools.Text.Find_Expressions.Directory_Type
            and then Parsed_S.Valid
            and then Parsed_S.Filter = Posix_Tools.Text.Find_Expressions.Socket_Type
            and then not Parsed_Invalid.Valid
            and then Parsed_Invalid.Filter = Posix_Tools.Text.Find_Expressions.Any_Type,
            "find type filter parsing checks");
      end;
      declare
         User_Only : constant Posix_Tools.Text.Owner_Groups.Parsed_Owner_Group :=
           Posix_Tools.Text.Owner_Groups.Parse_Owner_Group ("1000");
         User_Group : constant Posix_Tools.Text.Owner_Groups.Parsed_Owner_Group :=
           Posix_Tools.Text.Owner_Groups.Parse_Owner_Group ("1000:100");
         Group_Only : constant Posix_Tools.Text.Owner_Groups.Parsed_Owner_Group :=
           Posix_Tools.Text.Owner_Groups.Parse_Owner_Group (":100");
         User_Trailing : constant Posix_Tools.Text.Owner_Groups.Parsed_Owner_Group :=
           Posix_Tools.Text.Owner_Groups.Parse_Owner_Group ("1000:");
         Empty_Text : constant Posix_Tools.Text.Owner_Groups.Parsed_Owner_Group :=
           Posix_Tools.Text.Owner_Groups.Parse_Owner_Group ("");
      begin
         AUnit.Assertions.Assert
           (not User_Only.Has_Separator
            and then User_Only.Has_Owner
            and then User_Only.Owner_First = 1
            and then User_Only.Owner_Last = 4
            and then not User_Only.Has_Group
            and then User_Group.Has_Separator
            and then User_Group.Has_Owner
            and then User_Group.Owner_Last = 4
            and then User_Group.Has_Group
            and then User_Group.Group_First = 6
            and then User_Group.Group_Last = 8
            and then Group_Only.Has_Separator
            and then not Group_Only.Has_Owner
            and then Group_Only.Has_Group
            and then Group_Only.Group_First = 2
            and then Group_Only.Group_Last = 4
            and then User_Trailing.Has_Separator
            and then User_Trailing.Has_Owner
            and then not User_Trailing.Has_Group
            and then not Empty_Text.Has_Separator
            and then not Empty_Text.Has_Owner
            and then not Empty_Text.Has_Group,
            "chown owner/group splitter checks");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Find_Expressions.Type_Matches
           (Posix_Tools.Text.Find_Expressions.Any_Type,
            False, False, False, False, False,
            Posix_Tools.Text.Find_Expressions.No_Special_File)
         and then Posix_Tools.Text.Find_Expressions.Type_Matches
           (Posix_Tools.Text.Find_Expressions.Directory_Type,
            True, True, False, False, False,
            Posix_Tools.Text.Find_Expressions.No_Special_File)
         and then not Posix_Tools.Text.Find_Expressions.Type_Matches
           (Posix_Tools.Text.Find_Expressions.Directory_Type,
            False, True, False, False, False,
            Posix_Tools.Text.Find_Expressions.No_Special_File)
         and then Posix_Tools.Text.Find_Expressions.Type_Matches
           (Posix_Tools.Text.Find_Expressions.Symbolic_Link_Type,
            False, False, False, True, False,
            Posix_Tools.Text.Find_Expressions.No_Special_File)
         and then Posix_Tools.Text.Find_Expressions.Type_Matches
           (Posix_Tools.Text.Find_Expressions.Socket_Type,
            True, False, False, False, True,
            Posix_Tools.Text.Find_Expressions.Socket_File)
         and then not Posix_Tools.Text.Find_Expressions.Type_Matches
           (Posix_Tools.Text.Find_Expressions.Socket_Type,
            True, False, False, False, False,
            Posix_Tools.Text.Find_Expressions.Socket_File),
         "find type match predicate checks");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Numeric_Images.Fixed_Octal_Image (0, 3) = "000"
         and then Posix_Tools.Text.Numeric_Images.Fixed_Octal_Image (8#755#, 4) = "0755"
         and then Posix_Tools.Text.Numeric_Images.Fixed_Decimal_Image (42, 4) = "0042"
         and then Posix_Tools.Text.Numeric_Images.Two_Digit_Image (7) = "07"
         and then Posix_Tools.Text.Numeric_Images.Three_Digit_Image (365) = "365"
         and then Posix_Tools.Text.Numeric_Images.Four_Digit_Image (2026) = "2026"
         and then Posix_Tools.Text.Numeric_Images.Space_Two_Image (7) = " 7"
         and then Posix_Tools.Text.Numeric_Images.Fixed_Hex_Image (16#2a#, 4) = "002a"
         and then Posix_Tools.Text.Numeric_Images.Fixed_Hex_Image (16#beef#, 2) = "ef",
         "numeric image checks");
      declare
         Fixed : constant Posix_Tools.Text.Seq_Formats.Parsed_Seq_Format :=
           Posix_Tools.Text.Seq_Formats.Parse_Seq_Format ("value=%08.2f!");
         General : constant Posix_Tools.Text.Seq_Formats.Parsed_Seq_Format :=
           Posix_Tools.Text.Seq_Formats.Parse_Seq_Format ("[%g]");
      begin
         AUnit.Assertions.Assert
           (Fixed.Valid
            and then Fixed.Width = 8
            and then Fixed.Has_Precision
            and then Fixed.Precision = 2
            and then Fixed.Conversion = 'f'
            and then Fixed.Percent_Index = 7
            and then Fixed.Conversion_Index = 12
            and then General.Valid
            and then General.Width = 0
            and then not General.Has_Precision
            and then General.Conversion = 'g'
            and then not Posix_Tools.Text.Seq_Formats.Parse_Seq_Format ("%").Valid
            and then not Posix_Tools.Text.Seq_Formats.Parse_Seq_Format ("%d").Valid
            and then not Posix_Tools.Text.Seq_Formats.Parse_Seq_Format ("%1").Valid
            and then not Posix_Tools.Text.Seq_Formats.Parse_Seq_Format ("%f%g").Valid,
            "seq format parsing");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Seq_Formats.Valid_Render_Scale (18)
         and then not Posix_Tools.Text.Seq_Formats.Valid_Render_Scale (19)
         and then Posix_Tools.Text.Seq_Formats.Trimmed_Decimal (1200, 2) = "12.0"
         and then Posix_Tools.Text.Seq_Formats.Trimmed_Decimal (-1250, 2) = "-12.5"
         and then Posix_Tools.Text.Seq_Formats.Fixed_Decimal (12, 1, 3) = "1.200"
         and then Posix_Tools.Text.Seq_Formats.Fixed_Decimal (-12, 1, 0) = "-1"
         and then Posix_Tools.Text.Seq_Formats.Pad_Zero ("-12.5", 7) = "-0012.5"
         and then Posix_Tools.Text.Seq_Formats.Pad_Zero ("12.5", 6) = "0012.5",
         "seq decimal rendering helpers");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Stat_Formats.Render_Format
           ("%n %s %F %a %u %g %% %q \n\t\\\z%",
            "file.txt",
            "0644",
            "regular file",
            "100",
            "42",
            "2026-08-22 10:11:12 +0000",
            "1787393472",
            "2026-08-22 10:12:13 +0000",
            "1787393533",
            "2026-08-22 10:13:14 +0000",
            "1787393594",
            "200") =
         "file.txt 42 regular file 0644 200 100 % %q "
         & Character'Val (10)
         & Character'Val (9)
         & "\z%",
         "stat format renderer handles fields and escapes");
      declare
         use type Posix_Tools.Numbers.Count;
         use type Posix_Tools.Numbers.Parse_Status;
         use type Posix_Tools.Tail_Counts.Count_Origin;
         Plain : constant Posix_Tools.Tail_Counts.Parsed_Count :=
           Posix_Tools.Tail_Counts.Parse_Count ("10");
         From_Start : constant Posix_Tools.Tail_Counts.Parsed_Count :=
           Posix_Tools.Tail_Counts.Parse_Count ("+10");
         Plus_Only : constant Posix_Tools.Tail_Counts.Parsed_Count :=
           Posix_Tools.Tail_Counts.Parse_Count ("+");
      begin
         AUnit.Assertions.Assert
           (Plain.Status = Posix_Tools.Numbers.Valid
            and then Plain.Value = 10
            and then Plain.Origin = Posix_Tools.Tail_Counts.From_End
            and then From_Start.Status = Posix_Tools.Numbers.Valid
            and then From_Start.Value = 10
            and then From_Start.Origin = Posix_Tools.Tail_Counts.From_Start
            and then Plus_Only.Status = Posix_Tools.Numbers.Invalid_Syntax
            and then Plus_Only.Value = 0
            and then Plus_Only.Origin = Posix_Tools.Tail_Counts.From_Start,
            "tail count parser checks");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Find_Expressions.Is_Expression_Start ("!")
         and then Posix_Tools.Text.Find_Expressions.Is_Expression_Start ("(")
         and then Posix_Tools.Text.Find_Expressions.Is_Expression_Start ("-name")
         and then Posix_Tools.Text.Find_Expressions.Is_Expression_Start ("-print")
         and then Posix_Tools.Text.Find_Expressions.Is_Expression_Start ("-unknown")
         and then not Posix_Tools.Text.Find_Expressions.Is_Expression_Start ("")
         and then not Posix_Tools.Text.Find_Expressions.Is_Expression_Start ("path")
         and then not Posix_Tools.Text.Find_Expressions.Is_Expression_Start ("-"),
         "find expression start classifier checks");
      declare
         Default_Size : constant Positive := 2;
      begin
         AUnit.Assertions.Assert
           (Posix_Tools.Text.OD_Formats.Is_Address_Base_Spec ("n")
            and then Posix_Tools.Text.OD_Formats.Is_Address_Base_Spec ("o")
            and then Posix_Tools.Text.OD_Formats.Is_Address_Base_Spec ("d")
            and then Posix_Tools.Text.OD_Formats.Is_Address_Base_Spec ("x")
            and then not Posix_Tools.Text.OD_Formats.Is_Address_Base_Spec ("")
            and then not Posix_Tools.Text.OD_Formats.Is_Address_Base_Spec ("h")
            and then not Posix_Tools.Text.OD_Formats.Is_Address_Base_Spec ("od")
            and then Posix_Tools.Text.OD_Formats.Type_Size ('0', Default_Size).Valid
            and then Posix_Tools.Text.OD_Formats.Type_Size ('0', Default_Size).Size = 2
            and then Posix_Tools.Text.OD_Formats.Type_Size ('C', Default_Size).Valid
            and then Posix_Tools.Text.OD_Formats.Type_Size ('C', Default_Size).Size = 1
            and then Posix_Tools.Text.OD_Formats.Type_Size ('S', Default_Size).Valid
            and then Posix_Tools.Text.OD_Formats.Type_Size ('S', Default_Size).Size = 2
            and then Posix_Tools.Text.OD_Formats.Type_Size ('I', Default_Size).Valid
            and then Posix_Tools.Text.OD_Formats.Type_Size ('I', Default_Size).Size = 4
            and then Posix_Tools.Text.OD_Formats.Type_Size ('L', Default_Size).Valid
            and then Posix_Tools.Text.OD_Formats.Type_Size ('L', Default_Size).Size = 8
            and then not Posix_Tools.Text.OD_Formats.Type_Size ('F', Default_Size).Valid
            and then Posix_Tools.Text.OD_Formats.Type_Size ('F', Default_Size).Size = 2
            and then Posix_Tools.Text.OD_Formats.Is_Shorthand_Format_Option ('a')
            and then Posix_Tools.Text.OD_Formats.Is_Shorthand_Format_Option ('b')
            and then Posix_Tools.Text.OD_Formats.Is_Shorthand_Format_Option ('c')
            and then Posix_Tools.Text.OD_Formats.Is_Shorthand_Format_Option ('d')
            and then Posix_Tools.Text.OD_Formats.Is_Shorthand_Format_Option ('o')
            and then Posix_Tools.Text.OD_Formats.Is_Shorthand_Format_Option ('s')
            and then Posix_Tools.Text.OD_Formats.Is_Shorthand_Format_Option ('x')
            and then not Posix_Tools.Text.OD_Formats.Is_Shorthand_Format_Option ('f')
            and then not Posix_Tools.Text.OD_Formats.Is_Shorthand_Format_Option ('A'),
            "od format classifier checks");
         declare
            No_Base : constant Posix_Tools.Text.OD_Formats.Parsed_Address_Base :=
              Posix_Tools.Text.OD_Formats.Address_Base_For ("n");
            Octal_Base : constant Posix_Tools.Text.OD_Formats.Parsed_Address_Base :=
              Posix_Tools.Text.OD_Formats.Address_Base_For ("o");
            Decimal_Base : constant Posix_Tools.Text.OD_Formats.Parsed_Address_Base :=
              Posix_Tools.Text.OD_Formats.Address_Base_For ("d");
            Hex_Base : constant Posix_Tools.Text.OD_Formats.Parsed_Address_Base :=
              Posix_Tools.Text.OD_Formats.Address_Base_For ("x");
            Invalid_Base : constant Posix_Tools.Text.OD_Formats.Parsed_Address_Base :=
              Posix_Tools.Text.OD_Formats.Address_Base_For ("od");
         begin
            AUnit.Assertions.Assert
              (No_Base.Valid and then No_Base.Base = Posix_Tools.Text.OD_Formats.No_Address
               and then Octal_Base.Valid
               and then Octal_Base.Base = Posix_Tools.Text.OD_Formats.Octal_Address
               and then Decimal_Base.Valid
               and then Decimal_Base.Base = Posix_Tools.Text.OD_Formats.Decimal_Address
               and then Hex_Base.Valid
               and then Hex_Base.Base = Posix_Tools.Text.OD_Formats.Hex_Address
               and then not Invalid_Base.Valid
               and then Invalid_Base.Base = Posix_Tools.Text.OD_Formats.Octal_Address
               and then Posix_Tools.Text.OD_Formats.Address_Image
                 (Posix_Tools.Text.OD_Formats.No_Address, 64) = ""
               and then Posix_Tools.Text.OD_Formats.Address_Image
                 (Posix_Tools.Text.OD_Formats.Octal_Address, 64) = "0000100"
               and then Posix_Tools.Text.OD_Formats.Address_Image
                 (Posix_Tools.Text.OD_Formats.Decimal_Address, 64) = "64"
               and then Posix_Tools.Text.OD_Formats.Address_Image
                 (Posix_Tools.Text.OD_Formats.Hex_Address, 64) = "0000040",
               "od address base parser and image checks");
         end;
         AUnit.Assertions.Assert
           (Posix_Tools.Text.OD_Formats.Decimal_U64_Image (0) = "0"
            and then Posix_Tools.Text.OD_Formats.Decimal_U64_Image
              (Interfaces.Unsigned_64'Last) = "18446744073709551615"
            and then Posix_Tools.Text.OD_Formats.Hex_U64_Image (16#2a#, 4) = "002a"
            and then Posix_Tools.Text.OD_Formats.Octal_U64_Image (8#17#, 4) = "0017"
            and then Posix_Tools.Text.OD_Formats.Signed_Image (16#7f#, 1) = "127"
            and then Posix_Tools.Text.OD_Formats.Signed_Image (16#80#, 1) = "-128"
            and then Posix_Tools.Text.OD_Formats.Unit_Value ("AB", 1, 2) = 16#4241#
            and then Posix_Tools.Text.OD_Formats.Unit_Value ("A", 1, 2) = 16#41#
            and then Posix_Tools.Text.OD_Formats.Named_Field (Character'Val (0)) = " nul"
            and then Posix_Tools.Text.OD_Formats.Named_Field ('A') = "   A"
            and then Posix_Tools.Text.OD_Formats.Character_Field (Character'Val (10)) = "  \\n"
            and then Posix_Tools.Text.OD_Formats.Character_Field ('A') = "   A",
            "od rendering field checks");
         declare
            Decimal_Offset : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
              Posix_Tools.Text.OD_Formats.Offset_Count ("10", False);
            Octal_Offset : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
              Posix_Tools.Text.OD_Formats.Offset_Count ("010", False);
            Hex_Offset : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
              Posix_Tools.Text.OD_Formats.Offset_Count ("0x10", False);
            Block_Offset : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
              Posix_Tools.Text.OD_Formats.Offset_Count ("2b", True);
            Kilo_Offset : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
              Posix_Tools.Text.OD_Formats.Offset_Count ("2k", True);
            Mega_Offset : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
              Posix_Tools.Text.OD_Formats.Offset_Count ("1m", True);
            Block_Disallowed : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
              Posix_Tools.Text.OD_Formats.Offset_Count ("2b", False);
            Empty_Hex : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
              Posix_Tools.Text.OD_Formats.Offset_Count ("0x", True);
            Empty_Text : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
              Posix_Tools.Text.OD_Formats.Offset_Count ("", True);
            Hex_Suffix : constant Posix_Tools.Text.OD_Formats.Parsed_Offset_Count :=
              Posix_Tools.Text.OD_Formats.Offset_Count ("0x10k", True);
         begin
            AUnit.Assertions.Assert
              (Decimal_Offset.Valid and then Decimal_Offset.Value = 10
               and then Octal_Offset.Valid and then Octal_Offset.Value = 8
               and then Hex_Offset.Valid and then Hex_Offset.Value = 16
               and then Block_Offset.Valid and then Block_Offset.Value = 1_024
               and then Kilo_Offset.Valid and then Kilo_Offset.Value = 2_048
               and then Mega_Offset.Valid and then Mega_Offset.Value = 1_048_576
               and then not Block_Disallowed.Valid and then Block_Disallowed.Value = 0
               and then not Empty_Hex.Valid and then Empty_Hex.Value = 0
               and then not Empty_Text.Valid and then Empty_Text.Value = 0
               and then not Hex_Suffix.Valid and then Hex_Suffix.Value = 0,
               "od offset count parser checks");
         end;
         declare
            Named : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Dump_Format_Item ("ac", 1);
            Character_Item : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Dump_Format_Item ("ac", 2);
            Signed_4 : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Dump_Format_Item ("d4x1", 1);
            Hex_1 : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Dump_Format_Item ("d4x1", 3);
            Float_F : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Dump_Format_Item ("fF", 1);
            Float_L : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Dump_Format_Item ("fL", 1);
            Unsigned_S : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Dump_Format_Item ("uS", 1);
            Invalid_Size : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Dump_Format_Item ("d3", 1);
            Invalid_Float_Size : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Dump_Format_Item ("f2", 1);
            Invalid_Kind : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Dump_Format_Item ("z", 1);
            Shorthand_A : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Shorthand_Format_Item ('a');
            Shorthand_D : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Shorthand_Format_Item ('d');
            Shorthand_X : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Shorthand_Format_Item ('x');
            Invalid_Shorthand : constant Posix_Tools.Text.OD_Formats.Parsed_Dump_Format_Item :=
              Posix_Tools.Text.OD_Formats.Shorthand_Format_Item ('f');
         begin
            AUnit.Assertions.Assert
              (Named.Valid
               and then Named.Kind = Posix_Tools.Text.OD_Formats.Named_Byte
               and then Named.Size = 1
               and then Named.Next_Index = 2
               and then not Named.At_End
               and then Character_Item.Valid
               and then Character_Item.Kind = Posix_Tools.Text.OD_Formats.Character_Byte
               and then Character_Item.At_End
               and then Signed_4.Valid
               and then Signed_4.Kind = Posix_Tools.Text.OD_Formats.Signed_Integer
               and then Signed_4.Size = 4
               and then Signed_4.Next_Index = 3
               and then Hex_1.Valid
               and then Hex_1.Kind = Posix_Tools.Text.OD_Formats.Hex_Integer
               and then Hex_1.Size = 1
               and then Hex_1.At_End
               and then Float_F.Valid
               and then Float_F.Kind = Posix_Tools.Text.OD_Formats.Floating_Point
               and then Float_F.Size = 4
               and then Float_L.Valid
               and then Float_L.Size = 8
               and then Unsigned_S.Valid
               and then Unsigned_S.Kind = Posix_Tools.Text.OD_Formats.Unsigned_Integer
               and then Unsigned_S.Size = 2
               and then not Invalid_Size.Valid
               and then not Invalid_Float_Size.Valid
               and then not Invalid_Kind.Valid
               and then Shorthand_A.Valid
               and then Shorthand_A.Kind = Posix_Tools.Text.OD_Formats.Named_Byte
               and then Shorthand_A.Size = 1
               and then Shorthand_D.Valid
               and then Shorthand_D.Kind = Posix_Tools.Text.OD_Formats.Unsigned_Integer
               and then Shorthand_D.Size = 2
               and then Shorthand_X.Valid
               and then Shorthand_X.Kind = Posix_Tools.Text.OD_Formats.Hex_Integer
               and then Shorthand_X.Size = 2
               and then not Invalid_Shorthand.Valid,
               "od dump format item parser checks");
         end;
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Octal_Modes.Valid_Mode ("0755")
         and then Posix_Tools.Text.Octal_Modes.Mode_Value ("0755") = 8#755#
         and then not Posix_Tools.Text.Octal_Modes.Valid_Mode ("")
         and then not Posix_Tools.Text.Octal_Modes.Valid_Mode ("10000")
         and then not Posix_Tools.Text.Octal_Modes.Valid_Mode ("0788")
         and then Posix_Tools.Text.Octal_Modes.Mode_Value ("0788") = 0,
         "octal mode parsing checks");
      declare
         Parsed_Three : constant Posix_Tools.Text.Octal_Parsing.Parsed_Octal_Prefix :=
           Posix_Tools.Text.Octal_Parsing.Prefix_Value ("777x", 3);
         Parsed_Two   : constant Posix_Tools.Text.Octal_Parsing.Parsed_Octal_Prefix :=
           Posix_Tools.Text.Octal_Parsing.Prefix_Value ("123", 2);
         Parsed_None  : constant Posix_Tools.Text.Octal_Parsing.Parsed_Octal_Prefix :=
           Posix_Tools.Text.Octal_Parsing.Prefix_Value ("x77", 3);
      begin
         AUnit.Assertions.Assert
           (Parsed_Three.Count = 3
            and then Parsed_Three.Value = 8#777#
            and then Parsed_Two.Count = 2
            and then Parsed_Two.Value = 8#12#
            and then Parsed_None.Count = 0
            and then Parsed_None.Value = 0,
            "octal prefix parsing checks");
      end;
      declare
         Parsed_HM  : constant Posix_Tools.Text.Time_Fields.Parsed_Time :=
           Posix_Tools.Text.Time_Fields.Parse_HM_Or_HMS ("23:59");
         Parsed_HMS : constant Posix_Tools.Text.Time_Fields.Parsed_Time :=
           Posix_Tools.Text.Time_Fields.Parse_HM_Or_HMS ("01:02:03");
      begin
         AUnit.Assertions.Assert
           (Parsed_HM.Valid
            and then Parsed_HM.Hour = 23
            and then Parsed_HM.Minute = 59
            and then Parsed_HM.Second = 0
            and then Parsed_HMS.Valid
            and then Parsed_HMS.Hour = 1
            and then Parsed_HMS.Minute = 2
            and then Parsed_HMS.Second = 3
            and then Posix_Tools.Text.Time_Fields.Is_Leap_Year (2024)
            and then not Posix_Tools.Text.Time_Fields.Is_Leap_Year (2100)
            and then Posix_Tools.Text.Time_Fields.Is_Leap_Year (2000)
            and then Posix_Tools.Text.Time_Fields.Days_In_Month (2024, 2) = 29
            and then Posix_Tools.Text.Time_Fields.Days_In_Month (2023, 2) = 28
            and then Posix_Tools.Text.Time_Fields.Day_Of_Year (2024, 12, 31) = 366
            and then Posix_Tools.Text.Time_Fields.Day_Of_Year (2023, 12, 31) = 365
            and then not Posix_Tools.Text.Time_Fields.Parse_HM_Or_HMS ("24:00").Valid
            and then not Posix_Tools.Text.Time_Fields.Parse_HM_Or_HMS ("12:60").Valid
            and then not Posix_Tools.Text.Time_Fields.Parse_HM_Or_HMS ("12").Valid
            and then not Posix_Tools.Text.Time_Fields.Parse_HM_Or_HMS ("12::00").Valid,
            "time field parsing checks");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Touch_Fields.Month_Number ("jan") = 1
         and then Posix_Tools.Text.Touch_Fields.Month_Number ("September") = 9
         and then Posix_Tools.Text.Touch_Fields.Month_Number ("sept") = 9
         and then Posix_Tools.Text.Touch_Fields.Month_Number ("bad") = 0
         and then Posix_Tools.Text.Touch_Fields.Weekday_Number ("Mon") = 1
         and then Posix_Tools.Text.Touch_Fields.Weekday_Number ("thurs") = 4
         and then Posix_Tools.Text.Touch_Fields.Weekday_Number ("sunday") = 7
         and then Posix_Tools.Text.Touch_Fields.Weekday_Number ("weekday") = 0
         and then Posix_Tools.Text.Touch_Fields.Unit_Seconds ("sec") = 1
         and then Posix_Tools.Text.Touch_Fields.Unit_Seconds ("minutes") = 60
         and then Posix_Tools.Text.Touch_Fields.Unit_Seconds ("week") = 604_800
         and then Posix_Tools.Text.Touch_Fields.Unit_Seconds ("month") = 0
         and then Posix_Tools.Text.Touch_Fields.Relative_Direction_For ("next") = 1
         and then Posix_Tools.Text.Touch_Fields.Relative_Direction_For ("LAST") = -1
         and then Posix_Tools.Text.Touch_Fields.Relative_Direction_For ("this") = 0
         and then Posix_Tools.Text.Touch_Fields.Is_Ago ("AGO")
         and then not Posix_Tools.Text.Touch_Fields.Is_Ago ("before")
         and then Posix_Tools.Text.Touch_Fields.Valid_POSIX_Timestamp ("202401020304.05")
         and then Posix_Tools.Text.Touch_Fields.Valid_POSIX_Timestamp ("01020304")
         and then not Posix_Tools.Text.Touch_Fields.Valid_POSIX_Timestamp ("202413020304")
         and then not Posix_Tools.Text.Touch_Fields.Valid_POSIX_Timestamp ("202401020304.")
         and then not Posix_Tools.Text.Touch_Fields.Valid_POSIX_Timestamp ("202401020304.5")
         and then not Posix_Tools.Text.Touch_Fields.Valid_POSIX_Timestamp (""),
         "touch free-form date vocabulary checks");
      declare
         Slash_Normalized : constant Posix_Tools.Text.Touch_Fields.Normalized_Date_Time :=
           Posix_Tools.Text.Touch_Fields.Normalize_ISO_Date_Time ("2024/01/02t03:04:05");
         Fraction_Normalized : constant Posix_Tools.Text.Touch_Fields.Normalized_Date_Time :=
           Posix_Tools.Text.Touch_Fields.Normalize_ISO_Date_Time ("2024-01-02T03:04:05.987");
         Invalid_Fraction : constant Posix_Tools.Text.Touch_Fields.Normalized_Date_Time :=
           Posix_Tools.Text.Touch_Fields.Normalize_ISO_Date_Time ("2024-01-02T03:04:05.");
         Unchanged : constant Posix_Tools.Text.Touch_Fields.Normalized_Date_Time :=
           Posix_Tools.Text.Touch_Fields.Normalize_ISO_Date_Time ("2024-01-02T03:04:05");
      begin
         AUnit.Assertions.Assert
           (Slash_Normalized.Valid
            and then Slash_Normalized.Changed
            and then Slash_Normalized.Length = 19
            and then Slash_Normalized.Text (1 .. Slash_Normalized.Length) = "2024-01-02T03:04:05"
            and then Fraction_Normalized.Valid
            and then Fraction_Normalized.Changed
            and then Fraction_Normalized.Text (1 .. Fraction_Normalized.Length) = "2024-01-02T03:04:05"
            and then not Invalid_Fraction.Valid
            and then not Unchanged.Valid,
            "touch ISO date-time normalization");
      end;
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Escaping.Needs_Escaping ('A'),
         "escaping leaves printable text");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Escaping.Needs_Escaping (Character'Val (10)),
         "escaping marks control text");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Escaping.Escaped_Character_Length ('A') = 1,
         "printable escaped length");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Escaping.Escaped_Character_Length (Character'Val (127)) = 4,
         "delete escaped length");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Escaping.Escaped_Length
           ("A" & Character'Val (10) & Character'Val (127) & "Z") = 10,
         "mixed escaped length");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Escaping.Escape_Untrusted
           ("A" & Character'Val (10) & Character'Val (127) & "Z") = "A\x0A\x7FZ",
         "text escaping renders control bytes");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Printf_Escapes.Decode_Backslash_Text
           ("A\n\t\\B") =
         "A" & Character'Val (10) & Character'Val (9) & "\B"
         and then not Posix_Tools.Text.Printf_Escapes.Stop_Decoding ("A\n\t\\B"),
         "printf escapes decode named escapes");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Printf_Escapes.Decode_Backslash_Text
           ("\101\0\777") =
         "A" & Character'Val (0) & Character'Val (255)
         and then not Posix_Tools.Text.Printf_Escapes.Stop_Decoding ("\101\0\777"),
         "printf escapes decode octal bytes");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Printf_Escapes.Decode_Backslash_Text
           ("\q\") = "q\"
         and then not Posix_Tools.Text.Printf_Escapes.Stop_Decoding ("\q\"),
         "printf escapes preserve unknown and trailing escapes");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Printf_Escapes.Decode_Backslash_Text
           ("ab\ccd") = "ab"
         and then Posix_Tools.Text.Printf_Escapes.Stop_Decoding ("ab\ccd"),
         "printf escapes stop on c escape");
      AUnit.Assertions.Assert
        (Posix_Tools.Commands.Helpers.Escape_Untrusted
           (Character'Val (1) & "X") = "\x01X",
         "command helper delegates text escaping");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.File_Operands.Subject_Name ("-") = "standard input",
         "file operand subject names standard input");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.File_Operands.Subject_Name ("sample.txt") = "sample.txt",
         "file operand subject preserves filenames");
      declare
         First_Field : constant Posix_Tools.Text.File_Magic_Fields.Magic_Field :=
           Posix_Tools.Text.File_Magic_Fields.Next_Field ("12:ab\:cd:text:mime", 1);
         Second_Field : constant Posix_Tools.Text.File_Magic_Fields.Magic_Field :=
           Posix_Tools.Text.File_Magic_Fields.Next_Field ("12:ab\:cd:text:mime", 4);
         Third_Field : constant Posix_Tools.Text.File_Magic_Fields.Magic_Field :=
           Posix_Tools.Text.File_Magic_Fields.Next_Field ("12:ab\:cd:text:mime", 11);
         Last_Field : constant Posix_Tools.Text.File_Magic_Fields.Magic_Field :=
           Posix_Tools.Text.File_Magic_Fields.Next_Field ("12:ab\:cd:text:mime", 16);
      begin
         AUnit.Assertions.Assert
           (First_Field.Last = 2
            and then First_Field.Next = 4
            and then not First_Field.At_End
            and then Second_Field.Last = 9
            and then Second_Field.Next = 11
            and then not Second_Field.At_End
            and then Third_Field.Last = 14
            and then Third_Field.Next = 16
            and then not Third_Field.At_End
            and then Last_Field.Last = 19
            and then Last_Field.Next = 16
            and then Last_Field.At_End,
            "file magic escaped field splitting checks");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Glob_Fields.Closing_Bracket_From ("a[bc]d", 2) = 5,
         "glob bracket helper finds closing bracket");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Glob_Fields.Closing_Bracket_From ("a[bc", 2) = 0,
         "glob bracket helper reports unclosed bracket");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Glob_Fields.Bracket_Class_Matches ("[a-c]", 1, 5, 'b'),
         "glob bracket helper matches ranges");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Glob_Fields.Bracket_Class_Matches ("[!a-c]", 1, 6, 'b'),
         "glob bracket helper negates ranges");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Glob_Fields.Bracket_Class_Matches ("[^a-c]", 1, 6, 'z'),
         "glob bracket helper supports caret negation");
      declare
         use type Posix_Tools.Text.Diagnostic_Fields.Usage_Diagnostic_Kind;

         Missing : constant Posix_Tools.Text.Diagnostic_Fields.Usage_Diagnostic :=
           Posix_Tools.Text.Diagnostic_Fields.Classify_Usage_Message
             ("missing option argument '-n'");
         Extra   : constant Posix_Tools.Text.Diagnostic_Fields.Usage_Diagnostic :=
           Posix_Tools.Text.Diagnostic_Fields.Classify_Usage_Message
             ("extra operand 'file'");
         Plain   : constant Posix_Tools.Text.Diagnostic_Fields.Usage_Diagnostic :=
           Posix_Tools.Text.Diagnostic_Fields.Classify_Usage_Message
             ("unknown option -x");
      begin
         AUnit.Assertions.Assert
           (Missing.Kind = Posix_Tools.Text.Diagnostic_Fields.Missing_Option_Argument
            and then Missing.Payload_First = 26
            and then Missing.Payload_Last = 27,
            "diagnostic classifier finds missing option payload");
         AUnit.Assertions.Assert
           (Extra.Kind = Posix_Tools.Text.Diagnostic_Fields.Extra_Operand
            and then Extra.Payload_First = 16
            and then Extra.Payload_Last = 19,
            "diagnostic classifier finds extra operand payload");
         AUnit.Assertions.Assert
           (Plain.Kind = Posix_Tools.Text.Diagnostic_Fields.Plain
            and then not Posix_Tools.Text.Diagnostic_Fields.Has_Payload (Plain),
            "diagnostic classifier leaves unquoted messages plain");
      end;

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
