with Command_Tests.Surface_Smoke.Helpers;

package body Command_Tests.Surface_Smoke is
   overriding procedure Set_Up (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
   begin
      Command_Tests.Surface_Smoke.Helpers.Remove_Fixtures;
   end Set_Up;

   overriding procedure Tear_Down (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
   begin
      Command_Tests.Surface_Smoke.Helpers.Restore_Fixtures;
   end Tear_Down;
end Command_Tests.Surface_Smoke;
