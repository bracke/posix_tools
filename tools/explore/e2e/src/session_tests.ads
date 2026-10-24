with AUnit.Test_Fixtures;
with AUnit.Test_Suites;

--  Whole sessions: explore started, used, and quit through the terminal.
package Session_Tests is
   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Test_Start_And_Quit (T : in out Fixture);
   procedure Test_Browse_And_Preview (T : in out Fixture);
   procedure Test_Copy (T : in out Fixture);
   procedure Test_Resize (T : in out Fixture);
   procedure Test_Clipboard (T : in out Fixture);
   procedure Test_Image (T : in out Fixture);
   procedure Test_Shell_Command (T : in out Fixture);

   function Suite return AUnit.Test_Suites.Access_Test_Suite;
end Session_Tests;
