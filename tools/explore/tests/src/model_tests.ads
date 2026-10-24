with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Model_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Paths (T : in out Fixture);
   procedure Test_Open_And_Deliver (T : in out Fixture);
   procedure Test_Stale_Entries_Dropped (T : in out Fixture);
   procedure Test_Enter_And_Leave (T : in out Fixture);
   procedure Test_Cursor_And_Scroll (T : in out Fixture);
   procedure Test_Filter (T : in out Fixture);
   procedure Test_History_And_Visual (T : in out Fixture);
   procedure Test_Keymap (T : in out Fixture);
   procedure Test_Board (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Model_Tests;
