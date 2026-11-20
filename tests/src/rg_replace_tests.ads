with AUnit.Test_Fixtures;

--  Capture-aware replacement rendering for rg.
package Rg_Replace_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Replacement_Output (T : in out Fixture);
end Rg_Replace_Tests;
