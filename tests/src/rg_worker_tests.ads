with AUnit.Test_Fixtures;

--  Tests of rg's bounded native Ada worker pool.
package Rg_Worker_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Parallel_Search (T : in out Fixture);
end Rg_Worker_Tests;
