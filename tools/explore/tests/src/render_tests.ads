with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Render_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Layout (T : in out Fixture);
   procedure Test_Header (T : in out Fixture);
   procedure Test_Status_Gives_Way (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Render_Tests;
