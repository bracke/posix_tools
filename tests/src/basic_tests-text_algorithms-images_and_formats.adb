with AUnit.Assertions;
with Posix_Tools.Numbers;
with Posix_Tools.Tail_Counts;
with Posix_Tools.Text.Find_Expressions;
with Posix_Tools.Text.Numeric_Images;
with Posix_Tools.Text.Owner_Groups;
with Posix_Tools.Text.Seq_Formats;
with Posix_Tools.Text.Stat_Formats;

package body Basic_Tests.Text_Algorithms.Images_And_Formats is
   use type Posix_Tools.Text.Find_Expressions.Count_Relation;
   use type Posix_Tools.Text.Find_Expressions.Find_Type_Filter;

   procedure Run (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
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
   end Run;
end Basic_Tests.Text_Algorithms.Images_And_Formats;
