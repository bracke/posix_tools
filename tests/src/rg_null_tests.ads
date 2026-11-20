with AUnit.Test_Fixtures;

--  NUL-delimited search data and pathname output for rg.
package Rg_Null_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Nul_Modes (T : in out Fixture);
end Rg_Null_Tests;
