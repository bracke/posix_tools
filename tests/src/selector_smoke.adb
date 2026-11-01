with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Text;
with Tooling_Checks;
with Tooling_Support;

package body Selector_Smoke is
   use Tooling_Support;

   type Text_List is array (Positive range <>) of Ada.Strings.Unbounded.Unbounded_String;

   function "+" (Text : String) return Ada.Strings.Unbounded.Unbounded_String
     renames Ada.Strings.Unbounded.To_Unbounded_String;

   No_Text : constant Text_List (1 .. 0) := [others => <>];

   procedure Run is
      use Ada.Strings.Unbounded;

      Runner_Path : constant String := Built_Test_Runner_Path;

      --  Run the tests Option Value selects, once, and check what ran:
      --  every Present needle must be in the report and no Absent one.
      procedure Expect_Selection
        (Option  : String;
         Value   : String;
         Present : Text_List;
         Absent  : Text_List := No_Text)
      is
         Label    : constant String := "test selector " & Option & " " & Value;
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture
             (Label   => Label,
              Dir     => Root,
              Program => Runner_Path,
              Args    => Project_Tools.Processes.Arguments
                ([Project_Tools.Processes.Argument ("test"),
                  Project_Tools.Processes.Argument (Option),
                  Project_Tools.Processes.Argument (Value)]),
              Quiet   => True);
         Output   : constant String := To_String (Captured.Output);
      begin
         if Captured.Status /= 0 then
            --  The suite's own report says which test failed and why.
            Ada.Text_IO.Put_Line (Output);
            Tooling_Checks.Fail (Label & " failed with status" & Integer'Image (Captured.Status));
         end if;

         for Needle of Present loop
            if not Project_Tools.Text.Contains (Output, To_String (Needle)) then
               Tooling_Checks.Fail (Label & " did not run " & To_String (Needle));
            end if;
         end loop;

         for Needle of Absent loop
            if Project_Tools.Text.Contains (Output, To_String (Needle)) then
               Tooling_Checks.Fail (Label & " also ran " & To_String (Needle));
            end if;
         end loop;
      end Expect_Selection;

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

      --  A command's suite is its whole name: cat is not cp, tr is not
      --  true, id is not identity.
      Expect_Selection ("--suite", "cat", [+"command:cat "], [+"command:cp ", +"command:cksum "]);
      Expect_Selection ("--suite", "cp", [+"command:cp "], [+"command:cat "]);
      Expect_Selection ("--suite", "tr", [+"command:tr "], [+"command:true "]);
      Expect_Selection ("--suite", "id", [+"command:id "], [+"command:identity "]);
      Expect_Selection ("--suite", "xargs", [+"command:xargs "], [+"command:cat "]);
      Expect_Selection ("--suite", "root", [+"command:root "], [+"command:cat "]);
      Expect_Selection
        ("--suite", "command", [+"command:basename ", +"command:root "], [+"basic:", +"regression:"]);
      Expect_Selection ("--suite", "property", [+"property:"], [+"command:", +"basic:"]);
      Expect_Selection
        ("--category", "unit", [+"basic:numbers", +"command:basename ", +"regression:REG-CAT-0001"]);
      Expect_Selection ("--category", "integration", [+"command:root "], [+"command:cat "]);
      Expect_Selection
        ("--category", "conformance", [+"basic:command inventory"], [+"command:", +"basic:numbers"]);
      Expect_Selection
        ("--category",
         "regression",
         [+"regression:REG-CAT-0001",
          +"regression:REG-STDOUT-0004",
          +"regression:REG-ENV-0001",
          +"regression:REG-VERBOSE-0001",
          +"regression:REG-XARGS-0001"],
         [+"command:", +"basic:"]);
      Expect_Selection ("--category", "locale", [+"locale:help"], [+"command:", +"basic:"]);
      Expect_Selection ("--category", "presentation", [+"presentation:styling"], [+"command:", +"basic:"]);

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
