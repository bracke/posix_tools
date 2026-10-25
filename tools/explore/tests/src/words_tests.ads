with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Words_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Lane_Line (T : in out Fixture);
   procedure Test_Result_Line (T : in out Fixture);
   procedure Test_Job_Line (T : in out Fixture);
   procedure Test_Panel (T : in out Fixture);
   procedure Test_Configuration_Problem (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Words_Tests;
