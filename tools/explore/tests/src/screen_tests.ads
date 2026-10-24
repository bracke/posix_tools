with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Screen_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Put_And_Clip (T : in out Fixture);
   procedure Test_Wide_Characters (T : in out Fixture);
   procedure Test_Render_Writes_Only_Changes (T : in out Fixture);
   procedure Test_Format (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Screen_Tests;
