with AUnit.Assertions;
with Interfaces;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Text.Classification;
with Posix_Tools.Text.Escaping;
with Posix_Tools.Text.File_Magic_Fields;
with Posix_Tools.Text.File_Operands;
with Posix_Tools.Text.Glob;
with Posix_Tools.Text.Glob_Fields;
with Posix_Tools.Text.OD_Formats;
with Posix_Tools.Text.Octal_Modes;
with Posix_Tools.Text.Octal_Parsing;
with Posix_Tools.Text.Printf_Escapes;
with Posix_Tools.Text.Time_Fields;
with Posix_Tools.Text.Touch_Fields;
with Posix_Tools.Text.Whitespace_Data;

package body Basic_Tests.Text_Algorithms.Escaping_Time_And_Glob is
   use type Interfaces.Unsigned_64;
   use type Posix_Tools.Text.OD_Formats.Address_Base;
   use type Posix_Tools.Text.OD_Formats.Dump_Format_Kind;

   procedure Run (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
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
        (Posix_Tools.Text.File_Operands.Subject_Name ("-", "standardinput") = "standardinput",
         "file operand subject names standard input");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.File_Operands.Subject_Name ("sample.txt", "standard input") = "sample.txt",
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
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Glob_Fields.Closing_Bracket_From ("[]a]", 1) = 4
         and then Posix_Tools.Text.Glob_Fields.Closing_Bracket_From ("[!]a]", 1) = 5,
         "a bracket first in a class is one of its members");

      declare
         function M (Pattern, Text : String) return Boolean renames Posix_Tools.Text.Glob.Matches;
         Long : constant String := [1 .. 60 => 'a'];
      begin
         AUnit.Assertions.Assert
           (M ("*.txt", "notes.txt") and then not M ("*.txt", "notes.txt~") and then M ("*", "")
            and then M ("a*b*c", "aXbYc") and then not M ("a*b*c", "aXbY") and then M ("a?c", "abc")
            and then not M ("a?c", "ac") and then M ("**", "x") and then M ("", "") and then not M ("", "x"),
            "glob stars and question marks");
         AUnit.Assertions.Assert
           (M ("[]a]x", "]x") and then M ("[!]a]x", "bx") and then not M ("[!]a]x", "]x")
            and then M ("a[bc", "a[bc") and then M ("[a-c]*", "cat"),
            "glob classes, and an unclosed bracket as itself");
         AUnit.Assertions.Assert
           (M ("a\*", "a*") and then not M ("a\*", "ab") and then M ("\[x]", "[x]") and then M ("a\", "a\"),
            "a backslash makes the next character stand for itself");
         AUnit.Assertions.Assert
           (not M ("*a*a*a*a*a*a*a*a*a*a*a*a*b", Long),
            "many stars that cannot match end without trying every split");
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
   end Run;
end Basic_Tests.Text_Algorithms.Escaping_Time_And_Glob;
