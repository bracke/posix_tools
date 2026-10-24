with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

package Preview_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Base64 (T : in out Fixture);
   procedure Test_Placeholders (T : in out Fixture);
   procedure Test_PNG_Header (T : in out Fixture);
   procedure Test_Fit (T : in out Fixture);
   procedure Test_Transmit (T : in out Fixture);
   procedure Test_Build (T : in out Fixture);
   procedure Test_Archives (T : in out Fixture);
   procedure Test_Syntax (T : in out Fixture);
   procedure Test_Thumbnails (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Preview_Tests;
