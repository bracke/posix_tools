with Ada.Command_Line;
with AUnit;
with AUnit.Reporter.Text;
with AUnit.Run;
with E2E_Suites;

--  Runs explore end to end and exits non-zero when any test failed.
procedure Explore_E2E is
   use type AUnit.Status;

   function Runner is new AUnit.Run.Test_Runner_With_Status (E2E_Suites.Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   if Runner (Reporter) /= AUnit.Success then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Explore_E2E;
