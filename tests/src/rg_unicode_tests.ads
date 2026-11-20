with AUnit.Test_Fixtures;

--  End-to-end Unicode case compatibility for rg.
package Rg_Unicode_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Unicode_Case (T : in out Fixture);
end Rg_Unicode_Tests;
