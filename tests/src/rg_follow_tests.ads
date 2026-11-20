with AUnit.Test_Fixtures;

--  Symbolic-link traversal and ancestor-loop handling for rg.
package Rg_Follow_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Follow_Links (T : in out Fixture);
   procedure Test_One_File_System (T : in out Fixture);
end Rg_Follow_Tests;
