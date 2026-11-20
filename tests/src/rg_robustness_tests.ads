with AUnit.Test_Fixtures;

--  Fault-injection and deterministic property coverage for rg.
package Rg_Robustness_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Faults (T : in out Fixture);
   procedure Test_Fixed_String_Property (T : in out Fixture);
end Rg_Robustness_Tests;
