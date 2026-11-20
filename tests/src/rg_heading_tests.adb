with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Rg_Heading_Tests is
   use Ada.Strings.Unbounded;

   type Run_Outcome is record
      Output : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Run_Rg
     (Args     : Posix_Tools.Arguments.Vector;
      Terminal : Boolean := False) return Run_Outcome;

   function Run_Rg
     (Args     : Posix_Tools.Arguments.Vector;
      Terminal : Boolean := False) return Run_Outcome
   is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, Terminal);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Heading_Output (T : in out Fixture) is
      pragma Unreferenced (T);
      LF     : constant Character := ASCII.LF;
      First  : constant String := Test_Support.Work_Path ("rg-heading-first.txt");
      Second : constant String := Test_Support.Work_Path ("rg-heading-second.txt");
   begin
      Test_Support.Write_File
        (First,
         "zero" & LF
         & "hit one" & LF
         & "after" & LF
         & "gap" & LF
         & "before" & LF
         & "hit two" & LF
         & "tail" & LF);
      Test_Support.Write_File (Second, "start" & LF & "hit three" & LF & "end" & LF);

      declare
         Headings : constant Run_Outcome :=
           Run_Rg (["--heading", "-n", "hit", First, Second]);
         Suppressed_Names : constant Run_Outcome :=
           Run_Rg (["--heading", "-I", "-n", "hit", First, Second]);
         Context : constant Run_Outcome :=
           Run_Rg (["--heading", "-n", "-C1", "hit", First, Second]);
         Counts : constant Run_Outcome := Run_Rg (["--heading", "-c", "hit", First, Second]);
         No_Headings : constant Run_Outcome :=
           Run_Rg (["--heading", "--no-heading", "-n", "hit", First, Second]);
         Matches : constant Run_Outcome :=
           Run_Rg (["--heading", "-o", "hit", First, Second]);
         Automatic : constant Run_Outcome :=
           Run_Rg (["-n", "hit", First, Second], Terminal => True);
         Listed : constant Run_Outcome := Run_Rg (["--files", "--heading", First]);
      begin
         AUnit.Assertions.Assert
           (To_String (Headings.Output) =
              First & LF
              & "2:hit one" & LF
              & "6:hit two" & LF
              & LF
              & Second & LF
              & "2:hit three" & LF,
            "--heading writes one filename header per matching input section");
         AUnit.Assertions.Assert
           (To_String (Suppressed_Names.Output) =
              "2:hit one" & LF
              & "6:hit two" & LF
              & LF
              & "2:hit three" & LF,
            "-I suppresses heading names while retaining section separation");
         AUnit.Assertions.Assert
           (To_String (Context.Output) =
              First & LF
              & "1-zero" & LF
              & "2:hit one" & LF
              & "3-after" & LF
              & "--" & LF
              & "5-before" & LF
              & "6:hit two" & LF
              & "7-tail" & LF
              & LF
              & Second & LF
              & "1-start" & LF
              & "2:hit three" & LF
              & "3-end" & LF,
            "headings retain intra-file context separators and use blank lines between files");
         AUnit.Assertions.Assert
           (To_String (Counts.Output) = First & ":2" & LF & Second & ":1" & LF,
            "count modes ignore heading layout");
         AUnit.Assertions.Assert
           (To_String (No_Headings.Output) =
              First & ":2:hit one" & LF
              & First & ":6:hit two" & LF
              & Second & ":2:hit three" & LF,
            "--no-heading restores per-record filename prefixes");
         AUnit.Assertions.Assert
           (To_String (Matches.Output) =
              First & LF
              & "hit" & LF
              & "hit" & LF
              & LF
              & Second & LF
              & "hit" & LF,
            "match-only output participates in heading sections");
         AUnit.Assertions.Assert
           (To_String (Automatic.Output) = To_String (Headings.Output),
            "terminal output enables heading layout automatically");
         AUnit.Assertions.Assert
           (To_String (Listed.Output) = First & LF,
            "heading flags remain inert and accepted in --files mode");
      end;

      Test_Support.Delete_If_Exists (First);
      Test_Support.Delete_If_Exists (Second);
   end Test_Heading_Output;
end Rg_Heading_Tests;
