with Test_Support;

separate (Metadata_Checks.Source_Rules)
procedure Self_Test is
   LF : constant Character := Character'Val (10);
   Ordinary_Path : constant String :=
     Test_Support.Work_Path ("source-rules-parser-fixture.adb");
   Subunit_Path : constant String :=
     Test_Support.Work_Path ("source-rules-subunit-fixture.adb");
   Ordinary_Expected : constant String :=
     "source.rules.parser.fixture.test_numbers";
   Subunit_Expected : constant String :=
     "source_rules.parser_fixture.test_numbers";
   Registered : Procedure_Count_Maps.Map;
   Measured   : Procedure_Count_Maps.Map;

   procedure Check
     (Path     : String;
      Parent   : String;
      Expected : String;
      Expected_After : String;
      Prefix   : String);

   procedure Check
     (Path     : String;
      Parent   : String;
      Expected : String;
      Expected_After : String;
      Prefix   : String) is
   begin
      Registered.Clear;
      Measured.Clear;
      Increment (Registered, Parent & "|test_numbers");
      Increment (Registered, Parent & "|test_after");
      Test_Support.Write_File
        (Path,
         Prefix
         & "procedure Test_Declaration (Left : Integer; Right : Integer);" & LF
         & "procedure Test_Separate is separate;" & LF
         & "procedure Test_Generic is new Generic_Case;" & LF
         & "procedure Test_Numbers" & LF
         & "  (T : in out Fixture;" & LF
         & "   Pattern : String := ""separate (Wrong.Parent)"") is -- body" & LF
         & "   procedure Test_Nested is" & LF
         & "   begin" & LF
         & "      null;" & LF
         & "   end Test_Nested;" & LF
         & "begin" & LF
         & "   null;" & LF
         & "end;" & LF
         & "procedure Test_After (T : in out Fixture) is" & LF
         & "begin" & LF
         & "   null;" & LF
         & "end;" & LF);

      Require_Test_Procedure_Budgets
        (Path,
         Maximum    => 100,
         Registered => Registered,
         Measured   => Measured);
      if not Measured.Contains (Expected)
        or else Measured.Element (Expected) /= 1
        or else not Measured.Contains (Expected_After)
        or else Measured.Element (Expected_After) /= 1
      then
         Tooling_Checks.Fail
           ("test procedure and subunit parser self-test failed");
      end if;
   end Check;
begin
   Check
     (Ordinary_Path,
      "source.rules.parser.fixture",
      Ordinary_Expected,
      "source.rules.parser.fixture.test_after",
      "--  separate (Wrong.Parent)" & LF);
   Check
     (Subunit_Path,
      "source_rules.parser_fixture",
      Subunit_Expected,
      "source_rules.parser_fixture.test_after",
      "separate" & LF & "  (Source_Rules . Parser_Fixture)" & LF);
end Self_Test;
