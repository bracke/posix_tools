with AUnit.Assertions;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Find_Expressions;
with Posix_Tools.Text.Nice_Fields;
with Posix_Tools.Text.NL_Fields;
with Posix_Tools.Text.Paste_Delimiters;
with Posix_Tools.Text.Signal_Names;
with Posix_Tools.Text.Sort_Modifiers;
with Posix_Tools.Text.Xargs_Fields;

package body Basic_Tests.Text_Algorithms.Fields_And_File_Modes is
   use type Posix_Tools.Text.Find_Expressions.Count_Relation;
   use type Posix_Tools.Text.File_Modes.Permission_Mode_Status;
   use type Posix_Tools.Text.NL_Fields.Logical_Section;
   use type Posix_Tools.Text.NL_Fields.Number_Mode;
   use type Posix_Tools.Text.Signal_Names.Signal_Name;

   procedure Run (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
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
           Posix_Tools.Text.File_Modes.Apply_Symbolic_Mode ("u+q", 0);
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
           Posix_Tools.Text.File_Modes.Parse_Find_Permission_Mode ("u+q");
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
   end Run;
end Basic_Tests.Text_Algorithms.Fields_And_File_Modes;
