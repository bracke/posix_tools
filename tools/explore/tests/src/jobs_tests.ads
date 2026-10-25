with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Jobs_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Destination (T : in out Fixture);
   procedure Test_Copy_And_Delete (T : in out Fixture);
   procedure Test_Conflict_Question (T : in out Fixture);
   procedure Test_Cancel (T : in out Fixture);
   procedure Test_Queue_Bound (T : in out Fixture);
   procedure Test_Overlap (T : in out Fixture);
   procedure Test_Version (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Jobs_Tests;
