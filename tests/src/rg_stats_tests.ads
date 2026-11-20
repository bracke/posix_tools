with AUnit.Test_Fixtures;

--  Search accounting and statistics output for rg.
package Rg_Stats_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Statistics (T : in out Fixture);
end Rg_Stats_Tests;
