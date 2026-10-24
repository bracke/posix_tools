with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Input_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Plain_Keys (T : in out Fixture);
   procedure Test_Legacy_Sequences (T : in out Fixture);
   procedure Test_Progressive_Keys (T : in out Fixture);
   procedure Test_Escape_Ambiguity (T : in out Fixture);
   procedure Test_Split_Sequences (T : in out Fixture);
   procedure Test_Mouse (T : in out Fixture);
   procedure Test_Resize (T : in out Fixture);
   procedure Test_Paste (T : in out Fixture);
   procedure Test_Replies (T : in out Fixture);
   procedure Test_Unknown_Sequences (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Input_Tests;
