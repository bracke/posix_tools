with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

--  explore on a directory of 100,000 entries, timed through the terminal.
package Performance_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Large_Directory (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Performance_Tests;
