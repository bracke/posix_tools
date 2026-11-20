with AUnit.Test_Fixtures;

--  Structured debug and trace diagnostics for rg.
package Rg_Diagnostic_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Diagnostics (T : in out Fixture);
end Rg_Diagnostic_Tests;
