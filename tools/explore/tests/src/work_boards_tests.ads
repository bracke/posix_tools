with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Work_Boards_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Supersede (T : in out Fixture);
   procedure Test_Priority (T : in out Fixture);
   procedure Test_Deliver (T : in out Fixture);
   procedure Test_Cancellation (T : in out Fixture);
   procedure Test_Shut_Down (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Work_Boards_Tests;
