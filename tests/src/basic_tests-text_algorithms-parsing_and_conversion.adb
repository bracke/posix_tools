with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Numbers;
with Posix_Tools.Text.Base_Parsing;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Cut_Fields;
with Posix_Tools.Text.DD_Blocks;
with Posix_Tools.Text.DD_Conversion_Engine;
with Posix_Tools.Text.DD_Conversions;
with Posix_Tools.Text.DD_Operands;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Duration_Fields;
with Posix_Tools.Text.Hex_Digests;
with Posix_Tools.Text.Logical_Paths;
with Posix_Tools.Text.Matching;
with Posix_Tools.Text.Portable_Paths;
with Posix_Tools.Text.Sort_Modifiers;
with Posix_Tools.Text.Sort_Numeric;
with Posix_Tools.Text.Suffixes;
with Posix_Tools.Text.Tab_Stops;
with Posix_Tools.Text.Test_Operators;

package body Basic_Tests.Text_Algorithms.Parsing_And_Conversion is
   procedure Run (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
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
         Error   : Posix_Tools.Text.DD_Operands.Operand_Error;
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
         use type Posix_Tools.Text.DD_Operands.Operand_Error_Kind;

         Error : Posix_Tools.Text.DD_Operands.Operand_Error;
         Empty_Count_Rejected : constant Boolean :=
           not Posix_Tools.Text.DD_Operands.Parse_Argument ("count=", Bad_Count, Error);
         Empty_Count_Error : constant Posix_Tools.Text.DD_Operands.Operand_Error := Error;
         Block_Parsed : constant Boolean :=
           Posix_Tools.Text.DD_Operands.Parse_Argument ("conv=block", Missing_Cbs, Error);
         Missing_Cbs_Rejected : constant Boolean :=
           not Posix_Tools.Text.DD_Operands.Validate (Missing_Cbs, Error);
      begin
         AUnit.Assertions.Assert
           (Empty_Count_Rejected
            and then Empty_Count_Error.Kind = Posix_Tools.Text.DD_Operands.Invalid_Count
            and then Ada.Strings.Unbounded.To_String (Empty_Count_Error.Subject) = "count="
            and then Block_Parsed
            and then Missing_Cbs_Rejected
            and then Error.Kind = Posix_Tools.Text.DD_Operands.Invalid_Block_Size
            and then Ada.Strings.Unbounded.To_String (Error.Subject) = "cbs",
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
   end Run;
end Basic_Tests.Text_Algorithms.Parsing_And_Conversion;
