with AUnit.Test_Fixtures;

--  Context-window rendering and option interactions for rg.
package Rg_Context_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Context_Output (T : in out Fixture);
end Rg_Context_Tests;
