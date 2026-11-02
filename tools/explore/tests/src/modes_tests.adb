with AUnit.Assertions;
with AUnit.Test_Caller;
with Explore.Modes;

package body Modes_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);

   use Explore.Modes;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("modes:ask and leave", Test_Ask_And_Leave'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("modes:shown", Test_Shown'Access));
      return Result;
   end Suite;

   procedure Test_Ask_And_Leave (T : in out Fixture) is
      pragma Unreferenced (T);
      Mode   : Interaction_Mode := Viewing_Jobs;
      Resume : Interaction_Mode := Browsing;
   begin
      Ask (Mode, Resume, Answering);
      AUnit.Assertions.Assert (Mode = Answering and then Resume = Viewing_Jobs, "a question over the jobs panel");
      Leave (Mode, Resume);
      AUnit.Assertions.Assert (Mode = Viewing_Jobs and then Resume = Browsing, "answered, the panel is back");
      Leave (Mode, Resume);
      AUnit.Assertions.Assert (Mode = Browsing, "and closing it goes back to browsing");

      Mode := Filtering;
      Ask (Mode, Resume, Answering);
      AUnit.Assertions.Assert (Resume = Filtering, "a question over the filter");
      Leave (Mode, Resume);
      AUnit.Assertions.Assert (Mode = Filtering, "answered, the filter is typed on");

      Mode := Renaming;
      Ask (Mode, Resume, Confirming_Quit);
      AUnit.Assertions.Assert (Resume = Browsing, "a question over anything else returns to browsing");
      Leave (Mode, Resume);
      AUnit.Assertions.Assert (Mode = Browsing and then Resume = Browsing, "as it does");

      Mode := Jumping;
      Leave (Mode, Resume);
      AUnit.Assertions.Assert (Mode = Browsing, "a prompt left goes back to browsing");
   end Test_Ask_And_Leave;

   procedure Test_Shown (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Prompting (Renaming) and then Prompting (Shelling) and then not Prompting (Filtering)
         and then not Prompting (Answering),
         "the prompts");
      AUnit.Assertions.Assert
        (Panel_Open (Viewing_Jobs, Browsing) and then Panel_Open (Answering, Viewing_Jobs)
         and then Panel_Open (Confirming_Quit, Viewing_Jobs) and then not Panel_Open (Answering, Browsing)
         and then not Panel_Open (Renaming, Viewing_Jobs),
         "the jobs panel, beneath a question that interrupted it too");
      AUnit.Assertions.Assert
        (Editing (Filtering, Browsing) and then Editing (Answering, Filtering)
         and then not Editing (Answering, Browsing) and then not Editing (Browsing, Filtering),
         "the filter, beneath a question that interrupted it too");
   end Test_Shown;
end Modes_Tests;
