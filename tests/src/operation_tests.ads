with AUnit.Test_Fixtures;

--  Tests of the shared copy, move, and removal operations, and of the
--  commands that now use them.
package Operation_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Copy_Tree (T : in out Fixture);
   procedure Test_Copy_Conflicts (T : in out Fixture);
   procedure Test_Copy_Cancel (T : in out Fixture);
   procedure Test_Remove_Tree (T : in out Fixture);
   procedure Test_Move (T : in out Fixture);
   procedure Test_Mv_Into_Directory (T : in out Fixture);
   procedure Test_Copy_Kept_And_Stopped (T : in out Fixture);
   procedure Test_Rm_Keeps_Link_Targets (T : in out Fixture);
   procedure Test_Cp_Keeps_Broken_Links (T : in out Fixture);
end Operation_Tests;
