with AUnit.Test_Fixtures;

--  Filename heading rendering and result-mode interactions for rg.
package Rg_Heading_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Heading_Output (T : in out Fixture);
end Rg_Heading_Tests;
