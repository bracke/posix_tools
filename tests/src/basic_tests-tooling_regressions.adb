with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Metadata_Checks.Ada_Lexing;
with Metadata_Checks.Catalog_Defaults;
with Metadata_Checks.Catalog_Defaults.Tests;
with Metadata_Checks.Continuous_Integration.Tests;
with Metadata_Checks.Source_Rules.Tests;
with Metadata_Checks.Warning_Policy.Tests;
with Regression_Registry.Tests;
with Test_Support;

package body Basic_Tests.Tooling_Regressions is
   procedure Test_Catalog_Default_Parser (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Metadata_Checks.Catalog_Defaults.Tests.Run;
   end Test_Catalog_Default_Parser;

   procedure Test_Warning_Policy_Parser (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Metadata_Checks.Warning_Policy.Tests.Run;
   end Test_Warning_Policy_Parser;

   procedure Test_Source_Rules_Parser (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Metadata_Checks.Source_Rules.Tests.Run;
   end Test_Source_Rules_Parser;

   procedure Test_Continuous_Integration_Paths (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Metadata_Checks.Continuous_Integration.Tests.Run;
   end Test_Continuous_Integration_Paths;

   procedure Test_Ada_Lexing (T : in out Fixture) is
      pragma Unreferenced (T);
      Raw : constant String :=
        "Quote := '""'; After := 1; -- hidden" & Character'Val (10)
        & "Visible := 2;";
      View : constant String :=
        Metadata_Checks.Ada_Lexing.Code_View
          (Raw, Keep_String_Delimiters => False);
   begin
      AUnit.Assertions.Assert
        (Test_Support.Contains (View, "After := 1;"),
         "a double-quote character literal does not start a string");
      AUnit.Assertions.Assert
        (not Test_Support.Contains (View, "hidden"),
         "an Ada comment remains hidden after a character literal");
      AUnit.Assertions.Assert
        (Test_Support.Contains (View, "Visible := 2;"),
         "code after a character literal remains visible");
   end Test_Ada_Lexing;

   procedure Test_Work_Directory_Lifecycle (T : in out Fixture) is
      pragma Unreferenced (T);
      Directory : Test_Support.Work_Directory;
      First  : Ada.Strings.Unbounded.Unbounded_String;
      Second : Ada.Strings.Unbounded.Unbounded_String;
   begin
      First := Ada.Strings.Unbounded.To_Unbounded_String
        (Ada.Directories.Containing_Directory
           (Test_Support.Work_Path (Directory, "lifecycle-first")));
      Test_Support.Remove_Work_Directory (Directory);
      AUnit.Assertions.Assert
        (not Ada.Directories.Exists
           (Ada.Strings.Unbounded.To_String (First)),
         "test work directory is removed");
      Test_Support.Prepare_Work_Directory (Directory);
      Second := Ada.Strings.Unbounded.To_Unbounded_String
        (Ada.Directories.Containing_Directory
           (Test_Support.Work_Path (Directory, "lifecycle-second")));
      AUnit.Assertions.Assert
        (Ada.Directories.Exists
           (Ada.Strings.Unbounded.To_String (Second)),
         "test work directory can be removed and prepared again");
      Test_Support.Remove_Work_Directory (Directory);
   exception
      when others =>
         Test_Support.Remove_Work_Directory_Safely (Directory);
         raise;
   end Test_Work_Directory_Lifecycle;

   procedure Test_Regression_Registry_Parser (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Regression_Registry.Tests.Run;
   end Test_Regression_Registry_Parser;

   procedure Test_Sed_Catalog_Defaults (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Metadata_Checks.Catalog_Defaults.Require_Matching_Defaults
        ("tools/sed/share/sed/messages/catalog.txt",
         "tools/sed/src/library/sed-localization-defaults.adb");
   end Test_Sed_Catalog_Defaults;

   procedure Test_Awk_Catalog_Defaults (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Metadata_Checks.Catalog_Defaults.Require_Matching_Defaults
        ("tools/awk/resources/messages/catalog.txt",
         "tools/awk/src/library/awk_cli-localization-defaults.adb");
   end Test_Awk_Catalog_Defaults;
end Basic_Tests.Tooling_Regressions;
