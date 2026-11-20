with AUnit.Test_Fixtures;

package Rg_Color_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Color_Output (T : in out Fixture);
end Rg_Color_Tests;
