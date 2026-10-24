with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Search_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Matching (T : in out Fixture);
   procedure Test_Walk (T : in out Fixture);
   procedure Test_Search_Pane (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Search_Tests;
