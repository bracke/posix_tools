with AUnit.Test_Fixtures;

package Basic_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Numbers (T : in out Fixture);
   procedure Test_Option_Parsing (T : in out Fixture);
   procedure Test_Command_Inventory (T : in out Fixture);
   procedure Test_Paths (T : in out Fixture);
   procedure Test_Stream_Counting (T : in out Fixture);
   procedure Test_Stream_Line_Split (T : in out Fixture);
   procedure Test_Stream_File_Fixture (T : in out Fixture);
   procedure Test_Stream_UTF_8_Counting (T : in out Fixture);
   procedure Test_Version (T : in out Fixture);
end Basic_Tests;
