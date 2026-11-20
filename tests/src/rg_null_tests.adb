with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Rg_Null_Tests is
   use Ada.Strings.Unbounded;

   type Run_Outcome is record
      Output : Unbounded_String;
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
      Test_Contexts.Set_Standard_Input_Read_Limit (Context, 3);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Nul_Modes (T : in out Fixture) is
      pragma Unreferenced (T);
      LF     : constant Character := ASCII.LF;
      NUL    : constant Character := ASCII.NUL;
      Data   : constant String :=
        "needle before" & LF & "prefix" & NUL
        & "needle after" & LF & NUL;
      Groups : constant String :=
        "hit one" & NUL
        & "gap" & NUL
        & "miss" & NUL
        & "gap two" & NUL
        & "hit two" & NUL;
      First  : constant String := Test_Support.Work_Path ("rg-null-first.txt");
      Second : constant String := Test_Support.Work_Path ("rg-null-second.txt");
   begin
      declare
         Records : constant Run_Outcome := Run_Rg (["--null-data", "-n", "needle"], Data);
         Matches : constant Run_Outcome := Run_Rg (["--null-data", "-o", "needle"], Data);
         Counted : constant Run_Outcome := Run_Rg (["--null-data", "-c", "needle"], Data);
         Context : constant Run_Outcome := Run_Rg (["--null-data", "-n", "-C1", "hit"], Groups);
      begin
         AUnit.Assertions.Assert
           (To_String (Records.Output) =
              "1:needle before" & LF & "prefix" & NUL
              & "2:needle after" & LF & NUL,
            "--null-data preserves embedded newlines and NUL-terminates selected records");
         AUnit.Assertions.Assert
           (To_String (Matches.Output) = "needle" & NUL & "needle" & NUL,
            "match-only NUL-data output terminates every match with NUL");
         AUnit.Assertions.Assert
           (To_String (Counted.Output) = "2" & NUL,
            "NUL-data counts use the selected record terminator");
         AUnit.Assertions.Assert
           (To_String (Context.Output) =
              "1:hit one" & NUL
              & "2-gap" & NUL
              & "--" & NUL
              & "4-gap two" & NUL
              & "5:hit two" & NUL,
            "NUL-data context groups use NUL record separators without binary suppression");
      end;

      Test_Support.Write_File (First, "hit first" & LF);
      Test_Support.Write_File (Second, "hit second" & LF);
      declare
         Prefixed : constant Run_Outcome := Run_Rg (["-0", "-n", "hit", First, Second]);
         Counts : constant Run_Outcome := Run_Rg (["--null", "-c", "hit", First, Second]);
         Paths : constant Run_Outcome := Run_Rg (["--null", "-l", "hit", First, Second]);
         Files : constant Run_Outcome := Run_Rg (["--null", "--files", First, Second]);
         Heading : constant Run_Outcome :=
           Run_Rg (["--null", "--heading", "-n", "hit", First, Second]);
         Restored : constant Run_Outcome :=
           Run_Rg (["--null", "--no-null", "-n", "hit", First, Second]);
      begin
         AUnit.Assertions.Assert
           (To_String (Prefixed.Output) =
              First & NUL & "1:hit first" & LF
              & Second & NUL & "1:hit second" & LF,
            "-0 NUL-separates pathname fields without changing result terminators");
         AUnit.Assertions.Assert
           (To_String (Counts.Output) = First & NUL & "1" & LF & Second & NUL & "1" & LF,
            "--null applies to pathname fields in count output");
         AUnit.Assertions.Assert
           (To_String (Paths.Output) = First & NUL & Second & NUL,
            "--null terminates file-result paths with NUL");
         AUnit.Assertions.Assert
           (To_String (Files.Output) = First & NUL & Second & NUL,
            "--files uses NUL path records only when --null is active");
         AUnit.Assertions.Assert
           (To_String (Heading.Output) =
              First & NUL & "1:hit first" & LF
              & LF
              & Second & NUL & "1:hit second" & LF,
            "heading path records honor --null while section gaps remain line based");
         AUnit.Assertions.Assert
           (To_String (Restored.Output) =
              First & ":1:hit first" & LF & Second & ":1:hit second" & LF,
            "--no-null restores ordinary pathname separators");
      end;

      Test_Support.Delete_If_Exists (First);
      Test_Support.Delete_If_Exists (Second);
   end Test_Nul_Modes;
end Rg_Null_Tests;
