with AUnit.Test_Fixtures;

--  Tests of the file commands rm, cp, mv, ln, ls, chmod, and mkdir, and of
--  the shared operations, glob brackets, and UTF-8 decoding beneath them,
--  each holding a command to what POSIX asks of it.
package File_Command_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Rm_Refuses_Dot_And_Root (T : in out Fixture);
   procedure Test_Rm_Force_Reports_Failures (T : in out Fixture);
   procedure Test_Rm_Interactive_Per_Entry (T : in out Fixture);
   procedure Test_Rm_Mv_Prompts_Localized (T : in out Fixture);
   procedure Test_Ln_Same_File (T : in out Fixture);
   procedure Test_Move_By_Copying (T : in out Fixture);
   procedure Test_Mv_Diagnostics (T : in out Fixture);
   procedure Test_Cp_Link_Loop (T : in out Fixture);
   procedure Test_Cp_Link_Options (T : in out Fixture);
   procedure Test_Cp_Into_Itself_Through_Link (T : in out Fixture);
   procedure Test_Cp_Preserves_Mode_Bits (T : in out Fixture);
   procedure Test_Cp_Force_Replaces_Unwritable (T : in out Fixture);
   procedure Test_Cp_Interactive_Inside_Tree (T : in out Fixture);
   procedure Test_Cp_Leaves_Source_Alone (T : in out Fixture);
   procedure Test_Ls_Operands (T : in out Fixture);
   procedure Test_Chmod_Symbolic_Grammar (T : in out Fixture);
   procedure Test_Mkdir_Mode_And_Diagnostics (T : in out Fixture);
   procedure Test_Glob_Brackets (T : in out Fixture);
   procedure Test_UTF_8_Resynchronises (T : in out Fixture);
end File_Command_Tests;
