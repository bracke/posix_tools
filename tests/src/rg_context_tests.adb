with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Rg_Context_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;

   type Run_Outcome is record
      Output : Unbounded_String;
      Errors : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Run_Rg
     (Args  : Posix_Tools.Arguments.Vector;
      Input : String := "") return Run_Outcome;

   function Run_Rg
     (Args  : Posix_Tools.Arguments.Vector;
      Input : String := "") return Run_Outcome
   is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Test_Contexts.Set_Standard_Input (Context, Input);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Context_Output (T : in out Fixture) is
      pragma Unreferenced (T);
      LF     : constant Character := ASCII.LF;
      Input  : constant String :=
        "one" & LF
        & "before" & LF
        & "hit alpha" & LF
        & "middle" & LF
        & "hit beta" & LF
        & "after" & LF
        & "gap one" & LF
        & "gap two" & LF
        & "hit gamma" & LF
        & "tail" & LF;
      First  : constant String := Test_Support.Work_Path ("rg-context-first.txt");
      Second : constant String := Test_Support.Work_Path ("rg-context-second.txt");
   begin
      declare
         Surrounding : constant Run_Outcome :=
           Run_Rg (["-n", "-C1", "--context-separator=SEP", "hit"], Input);
         Precedence : constant Run_Outcome :=
           Run_Rg (["-n", "-A1", "-C2", "-B0", "hit"], Input);
         Match_Only : constant Run_Outcome := Run_Rg (["-n", "-o", "-C1", "hit"], Input);
         Inverted : constant Run_Outcome := Run_Rg (["-n", "-v", "-C1", "hit"], Input);
         Capped_Context : constant Run_Outcome :=
           Run_Rg (["-n", "-m1", "-C2", "hit"], Input);
         Long_Forms : constant Run_Outcome :=
           Run_Rg
             (["-n", "--context=3", "--before-context", "1", "--after-context=0", "hit"],
              Input);
         Invalid : constant Run_Outcome := Run_Rg (["--context=bad", "hit"], Input);
      begin
         AUnit.Assertions.Assert
           (To_String (Surrounding.Output) =
              "2-before" & LF
              & "3:hit alpha" & LF
              & "4-middle" & LF
              & "5:hit beta" & LF
              & "6-after" & LF
              & "SEP" & LF
              & "8-gap two" & LF
              & "9:hit gamma" & LF
              & "10-tail" & LF,
            "overlapping context windows merge and disjoint groups use the configured separator");
         AUnit.Assertions.Assert
           (To_String (Precedence.Output) =
              "3:hit alpha" & LF
              & "4-middle" & LF
              & "5:hit beta" & LF
              & "6-after" & LF
              & "--" & LF
              & "9:hit gamma" & LF
              & "10-tail" & LF,
            "specific leading and trailing context values override -C regardless of order");
         AUnit.Assertions.Assert
           (To_String (Match_Only.Output) =
              "2-before" & LF
              & "3:hit" & LF
              & "4-middle" & LF
              & "5:hit" & LF
              & "6-after" & LF
              & "--" & LF
              & "8-gap two" & LF
              & "9:hit" & LF
              & "10-tail" & LF,
            "-o slices selected records while retaining whole context records");
         AUnit.Assertions.Assert
           (To_String (Inverted.Output) =
              "1:one" & LF
              & "2:before" & LF
              & "3-hit alpha" & LF
              & "4:middle" & LF
              & "5-hit beta" & LF
              & "6:after" & LF
              & "7:gap one" & LF
              & "8:gap two" & LF
              & "9-hit gamma" & LF
              & "10:tail" & LF,
            "inverted matches use context delimiters for unselected matching records");
         AUnit.Assertions.Assert
           (To_String (Capped_Context.Output) =
              "1-one" & LF
              & "2-before" & LF
              & "3:hit alpha" & LF
              & "4-middle" & LF
              & "5:hit beta" & LF,
            "-m drains but does not extend the trailing context window");
         AUnit.Assertions.Assert
           (To_String (Long_Forms.Output) =
              "2-before" & LF
              & "3:hit alpha" & LF
              & "4-middle" & LF
              & "5:hit beta" & LF
              & "--" & LF
              & "8-gap two" & LF
              & "9:hit gamma" & LF,
            "specific long context options override --context regardless of order");
         AUnit.Assertions.Assert
           (Invalid.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains
              (To_String (Invalid.Errors), "invalid value for --context"),
            "invalid context counts are rejected explicitly");
      end;

      Test_Support.Write_File (First, "hit first" & LF);
      Test_Support.Write_File (Second, "hit second" & LF);
      declare
         Multiple : constant Run_Outcome := Run_Rg (["-n", "-C1", "hit", First, Second]);
      begin
         AUnit.Assertions.Assert
           (To_String (Multiple.Output) =
              First & ":1:hit first" & LF
              & "--" & LF
              & Second & ":1:hit second" & LF,
            "context groups in separate explicit files are separated");
      end;
      Test_Support.Delete_If_Exists (First);
      Test_Support.Delete_If_Exists (Second);
   end Test_Context_Output;
end Rg_Context_Tests;
