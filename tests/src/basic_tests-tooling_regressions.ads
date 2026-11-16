package Basic_Tests.Tooling_Regressions is
   procedure Test_Catalog_Default_Parser (T : in out Fixture);
   procedure Test_Warning_Policy_Parser (T : in out Fixture);
   procedure Test_Source_Rules_Parser (T : in out Fixture);
   procedure Test_Continuous_Integration_Paths (T : in out Fixture);
   procedure Test_Ada_Lexing (T : in out Fixture);
   procedure Test_Work_Directory_Lifecycle (T : in out Fixture);
   procedure Test_Regression_Registry_Parser (T : in out Fixture);
   procedure Test_Sed_Catalog_Defaults (T : in out Fixture);
   procedure Test_Awk_Catalog_Defaults (T : in out Fixture);
end Basic_Tests.Tooling_Regressions;
