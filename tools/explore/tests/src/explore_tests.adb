with Ada.Command_Line;
with AUnit;
with AUnit.Reporter.Text;
with AUnit.Run;
with Explore_Suites;

--  Runs every explore test and exits non-zero when any of them failed.
procedure Explore_Tests is
   use type AUnit.Status;

   function Runner is new AUnit.Run.Test_Runner_With_Status (Explore_Suites.Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   if Runner (Reporter) /= AUnit.Success then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Explore_Tests;
