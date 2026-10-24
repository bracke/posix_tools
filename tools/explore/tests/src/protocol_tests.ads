with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Protocol_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Identity_Parsing (T : in out Fixture);
   procedure Test_Identity_Rejection (T : in out Fixture);
   procedure Test_Identity_Query (T : in out Fixture);
   procedure Test_Passthrough (T : in out Fixture);
   procedure Test_Screen_Modes_Balance (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Protocol_Tests;
