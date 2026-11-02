with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Modes_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Ask_And_Leave (T : in out Fixture);
   procedure Test_Shown (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Modes_Tests;
