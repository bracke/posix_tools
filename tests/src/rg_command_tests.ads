with AUnit.Test_Fixtures;

--  Tests of rg's command lifecycle and Regexp compatibility boundary.
package Rg_Command_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Help_And_Version (T : in out Fixture);
   procedure Test_Pattern_Adapter (T : in out Fixture);
   procedure Test_Default_Syntax_Policy (T : in out Fixture);
   procedure Test_Option_Parsing (T : in out Fixture);
   procedure Test_Sequential_Search (T : in out Fixture);
   procedure Test_Pattern_Files (T : in out Fixture);
   procedure Test_Ignore_Policy (T : in out Fixture);
   procedure Test_Ignore_Controls (T : in out Fixture);
   procedure Test_Recursive_Traversal (T : in out Fixture);
   procedure Test_File_Listing (T : in out Fixture);
   procedure Test_Glob_Filtering (T : in out Fixture);
   procedure Test_File_Types (T : in out Fixture);
   procedure Test_Rendering (T : in out Fixture);
   procedure Test_Selection_Controls (T : in out Fixture);
   procedure Test_Result_Modes (T : in out Fixture);
   procedure Test_Match_Result_Modes (T : in out Fixture);
end Rg_Command_Tests;
