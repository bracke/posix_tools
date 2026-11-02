with AUnit.Test_Fixtures;

--  Tests of grep run through a capturing context: its output as greplib's
--  events arrive, its exit status, its pattern lists, its context groups,
--  and the translation of basic regular expressions.
package Grep_Command_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Output_Is_Not_Truncated (T : in out Fixture);
   procedure Test_Output_Failure (T : in out Fixture);
   procedure Test_Quiet_Selection_Wins_Over_Errors (T : in out Fixture);
   procedure Test_Context_Separators (T : in out Fixture);
   procedure Test_Pattern_Lists (T : in out Fixture);
   procedure Test_Standard_Input_Label (T : in out Fixture);
   procedure Test_Help_And_Version (T : in out Fixture);
   procedure Test_Basic_To_Extended (T : in out Fixture);
   procedure Test_Event_Rendering (T : in out Fixture);
end Grep_Command_Tests;
