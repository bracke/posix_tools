with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Settings_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Bindings (T : in out Fixture);
   procedure Test_Configuration (T : in out Fixture);
   procedure Test_Problems (T : in out Fixture);
   procedure Test_Readers (T : in out Fixture);
   procedure Test_Sort_Keys (T : in out Fixture);
   procedure Test_Shift (T : in out Fixture);
   procedure Test_Bookmarks (T : in out Fixture);
   procedure Test_Openers (T : in out Fixture);
   procedure Test_Shell (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Settings_Tests;
