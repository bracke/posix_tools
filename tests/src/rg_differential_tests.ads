with AUnit.Test_Fixtures;

--  Differential compatibility checks against the pinned ripgrep executable.
package Rg_Differential_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Reference_Differential (T : in out Fixture);
end Rg_Differential_Tests;
