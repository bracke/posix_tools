with AUnit.Test_Fixtures;

--  Complete WHATWG decoder-family coverage for rg.
package Rg_Encoding_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Encoding_Surface (T : in out Fixture);
end Rg_Encoding_Tests;
