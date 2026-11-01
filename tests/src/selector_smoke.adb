with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Text;
with Tooling_Checks;
with Tooling_Support;

package body Selector_Smoke is
   use Tooling_Support;

   procedure Run is
      use Ada.Strings.Unbounded;

      Runner_Path : constant String := Built_Test_Runner_Path;

      procedure Expect_Selector
        (Label  : String;
         Args   : Project_Tools.Processes.Argument_Vectors.Vector;
         Needle : String)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture
             (Label   => Label,
              Dir     => Root,
              Program => Runner_Path,
              Args    => Args,
              Quiet   => True);
      begin
         if Captured.Status /= 0 then
            --  The suite's own report says which test failed and why.
            Ada.Text_IO.Put_Line (To_String (Captured.Output));
            Tooling_Checks.Fail
              (Label & " failed with status" & Integer'Image (Captured.Status));
         elsif not Project_Tools.Text.Contains (To_String (Captured.Output), Needle) then
            Tooling_Checks.Fail
              (Label & " output did not include " & Needle);
         end if;
      end Expect_Selector;

      procedure Expect_Usage_Error
        (Label : String;
         Args  : Project_Tools.Processes.Argument_Vectors.Vector)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture_Command
             (Command    => Runner_Path,
              Arguments  => Args,
              Err_To_Out => True);
      begin
         if Captured.Status /= 2 then
            Tooling_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status)
               & " instead of usage status 2");
         end if;
      end Expect_Usage_Error;
   begin
      if not Project_Tools.Files.File_Exists (Runner_Path) then
         Tooling_Checks.Fail ("built test runner is missing for selector smoke tests");
      end if;

      Expect_Selector
        ("test selector suite cat",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("cat")]),
         "command:cat");
      Expect_Selector
        ("test selector suite cp",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("cp")]),
         "command:cp");
      Expect_Selector
        ("test selector suite xargs",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("xargs")]),
         "command:xargs");
      Expect_Selector
        ("test selector suite root",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("root")]),
         "command:root");
      Expect_Selector
        ("test selector suite command",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("command")]),
         "command:basename");
      Expect_Selector
        ("test selector category unit",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("unit")]),
         "basic:numbers");
      Expect_Selector
        ("test selector category integration",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("integration")]),
         "command:root");
      Expect_Selector
        ("test selector category conformance",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("conformance")]),
         "basic:command inventory");
      Expect_Selector
        ("test selector category regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-CAT-0001");
      Expect_Selector
        ("test selector command regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-STDOUT-0004");
      Expect_Selector
        ("test selector env regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-ENV-0001");
      Expect_Selector
        ("test selector verbose regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-VERBOSE-0001");
      Expect_Selector
        ("test selector xargs regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-XARGS-0001");
      Expect_Selector
        ("test selector category locale",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("locale")]),
         "locale:help");
      Expect_Selector
        ("test selector category presentation",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("presentation")]),
         "presentation:styling");
      Expect_Usage_Error
        ("test selector missing suite value",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite")]));
      Expect_Usage_Error
        ("test selector unknown suite",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("unknown")]));
      Expect_Usage_Error
        ("test selector unknown category",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("unknown")]));

      Ada.Text_IO.Put_Line ("test selector smoke checks passed");
   end Run;
end Selector_Smoke;
