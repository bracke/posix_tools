with AUnit.Test_Fixtures;

--  JSON Lines event output for rg.
package Rg_Json_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Json_Output (T : in out Fixture);
end Rg_Json_Tests;
