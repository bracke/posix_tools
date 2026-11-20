with AUnit.Test_Fixtures;

--  Deterministic per-root pathname ordering for rg.
package Rg_Sort_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Path_Sorting (T : in out Fixture);
end Rg_Sort_Tests;
