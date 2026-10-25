with AUnit.Test_Fixtures;

--  The command surface tests, one routine per command or small family, in
--  the child packages. Each starts with no fixtures left by another and
--  leaves the tracked fixtures as git has them, however it ends.
package Command_Tests.Surface_Smoke is
   type Surface_Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   overriding procedure Set_Up (T : in out Surface_Fixture);
   overriding procedure Tear_Down (T : in out Surface_Fixture);
end Command_Tests.Surface_Smoke;
