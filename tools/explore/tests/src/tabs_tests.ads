with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Tabs_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Open (T : in out Fixture);
   procedure Test_Switch (T : in out Fixture);
   procedure Test_Close (T : in out Fixture);
   procedure Test_Round (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Tabs_Tests;
