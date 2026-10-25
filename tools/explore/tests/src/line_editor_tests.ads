with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Line_Editor_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Typing (T : in out Fixture);
   procedure Test_Backspace (T : in out Fixture);
   procedure Test_Ending_Keys (T : in out Fixture);
   procedure Test_Paste (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Line_Editor_Tests;
