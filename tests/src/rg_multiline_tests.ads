with AUnit.Test_Fixtures;

--  Bounded multiline matching and rendering for rg.
package Rg_Multiline_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Multiline_Search (T : in out Fixture);
end Rg_Multiline_Tests;
