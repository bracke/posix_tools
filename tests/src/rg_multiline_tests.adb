with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Rg_Multiline_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;

   type Run_Outcome is record
      Output : Unbounded_String;
      Errors : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Run_Rg (Args : Posix_Tools.Arguments.Vector) return Run_Outcome;

   function Run_Rg (Args : Posix_Tools.Arguments.Vector) return Run_Outcome is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Multiline_Search (T : in out Fixture) is
      pragma Unreferenced (T);
      LF   : constant Character := ASCII.LF;
      Path : constant String := Test_Support.Work_Path ("rg-multiline.txt");
   begin
      Test_Support.Write_File
        (Path,
         "zero" & LF
         & "start" & LF
         & "middle" & LF
         & "end" & LF
         & "tail" & LF
         & "start middle" & LF);

      declare
         Basic : constant Run_Outcome := Run_Rg (["-U", "-n", "start\nmiddle", Path]);
         Fragments : constant Run_Outcome :=
           Run_Rg (["-U", "-n", "--column", "-o", "art\nmid", Path]);
         Count_Lines : constant Run_Outcome := Run_Rg (["-U", "-c", "start\nmiddle", Path]);
         Count_Matches : constant Run_Outcome :=
           Run_Rg (["-U", "--count-matches", "start\nmiddle", Path]);
         Context : constant Run_Outcome :=
           Run_Rg (["-U", "-n", "-A1", "-B1", "start\nmiddle", Path]);
         Inverted : constant Run_Outcome := Run_Rg (["-U", "-n", "-v", "start\nmiddle", Path]);
         Dot : constant Run_Outcome := Run_Rg (["-U", "-n", "start.middle", Path]);
         Dotall : constant Run_Outcome :=
           Run_Rg (["-U", "--multiline-dotall", "-n", "start.middle", Path]);
         Bounded : constant Run_Outcome := Run_Rg (["-U", "-n", "-m1", "start|middle", Path]);
         Newlines : constant Run_Outcome := Run_Rg (["-U", "-n", "\n", Path]);
         Newline_Fragments : constant Run_Outcome := Run_Rg (["-U", "-n", "-o", "\n", Path]);
         Nul_Path : constant String := Test_Support.Work_Path ("rg-multiline-nul.bin");
      begin
         AUnit.Assertions.Assert
           (Basic.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Basic.Output) = "2:start" & LF & "3:middle" & LF,
            "-U selects every line touched by a spanning match");
         AUnit.Assertions.Assert
           (To_String (Fragments.Output) = "2:3:art" & LF & "3:3:mid" & LF,
            "multiline match-only output splits fragments and preserves the start column");
         AUnit.Assertions.Assert
           (To_String (Count_Lines.Output) = "1" & LF
            and then To_String (Count_Matches.Output) = "1" & LF,
            "multiline count modes report match-start lines and matches");
         AUnit.Assertions.Assert
           (To_String (Context.Output) =
              "1-zero" & LF & "2:start" & LF & "3:middle" & LF & "4-end" & LF,
            "multiline context surrounds the complete touched range");
         AUnit.Assertions.Assert
           (To_String (Inverted.Output) =
              "1:zero" & LF & "4:end" & LF & "5:tail" & LF & "6:start middle" & LF,
            "multiline inversion excludes every line touched by a match");
         AUnit.Assertions.Assert
           (To_String (Dot.Output) = "6:start middle" & LF
            and then To_String (Dotall.Output) =
              "2:start" & LF & "3:middle" & LF & "6:start middle" & LF,
            "--multiline-dotall controls whether dot crosses a line terminator");
         AUnit.Assertions.Assert
           (To_String (Bounded.Output) = "2:start" & LF,
            "multiline max-count limits distinct match-start lines");
         AUnit.Assertions.Assert
           (To_String (Newlines.Output) =
              "1:zero" & LF & "2:start" & LF & "3:middle" & LF
              & "4:end" & LF & "5:tail" & LF & "6:start middle" & LF
            and then Length (Newline_Fragments.Output) = 0
            and then Newline_Fragments.Status = Posix_Tools.Exit_Status.Success,
            "newline-only matches select preceding records without match-only fragments");
         Test_Support.Write_File
           (Nul_Path, "zero" & ASCII.NUL & "start" & ASCII.NUL & "middle" & ASCII.NUL);
         declare
            Nul_Multiline : constant Run_Outcome :=
              Run_Rg (["-U", "--null-data", "-n", "start.middle", Nul_Path]);
         begin
            AUnit.Assertions.Assert
              (Nul_Multiline.Status = Posix_Tools.Exit_Status.Success
               and then To_String (Nul_Multiline.Output) =
                 "2:start" & ASCII.NUL & "3:middle" & ASCII.NUL,
               "multiline mode searches and renders NUL-delimited records, output="""
               & To_String (Nul_Multiline.Output) & """");
         end;
         Test_Support.Delete_If_Exists (Nul_Path);
      end;

      Test_Support.Delete_If_Exists (Path);
   end Test_Multiline_Search;
end Rg_Multiline_Tests;
