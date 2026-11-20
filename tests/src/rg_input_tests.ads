with AUnit.Test_Fixtures;

--  Binary-input and discovered-file size policies for rg.
package Rg_Input_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Binary_Controls (T : in out Fixture);
   procedure Test_Encoding (T : in out Fixture);
   procedure Test_Max_File_Size (T : in out Fixture);
end Rg_Input_Tests;
