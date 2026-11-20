with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Rg_Replace_Tests is
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

   procedure Test_Replacement_Output (T : in out Fixture) is
      pragma Unreferenced (T);
      LF   : constant Character := ASCII.LF;
      Path : constant String := Test_Support.Work_Path ("rg-replace.txt");
   begin
      Test_Support.Write_File
        (Path,
         "zero" & LF
         & "start" & LF
         & "middle" & LF
         & "start middle" & LF);

      declare
         Numbered : constant Run_Outcome :=
           Run_Rg (["-n", "-r", "$2-$1", "(start) (middle)", Path]);
         Named : constant Run_Outcome :=
           Run_Rg (["-n", "-r", "<$left/$right>", "(?P<left>start) (?P<right>middle)", Path]);
         Multiple : constant Run_Outcome :=
           Run_Rg (["-n", "-e", "(start)", "-e", "(middle)", "-r", "<$1/$2>", Path]);
         Dollars : constant Run_Outcome := Run_Rg (["-n", "-r", "$$", "start", Path]);
         Unknown : constant Run_Outcome := Run_Rg (["-n", "-r", "<$missing>", "start", Path]);
         Match_Only : constant Run_Outcome :=
           Run_Rg (["-n", "-o", "-r", "$2-$1", "(start) (middle)", Path]);
         Context : constant Run_Outcome := Run_Rg (["-n", "-B1", "-A1", "-r", "X", "start", Path]);
         Inverted : constant Run_Outcome := Run_Rg (["-n", "-v", "-r", "X", "start", Path]);
         Counted : constant Run_Outcome := Run_Rg (["-c", "-r", "X", "start", Path]);
         Empty : constant Run_Outcome := Run_Rg (["-n", "--replace=", "start", Path]);
         Duplicate : constant Run_Outcome :=
           Run_Rg (["-e", "(?P<x>start)", "-e", "(?P<x>middle)", "-r", "$x", Path]);
         Multiline : constant Run_Outcome :=
           Run_Rg (["-U", "-n", "-r", "$2/$1", "(start)\n(middle)", Path]);
         Multiline_Context : constant Run_Outcome :=
           Run_Rg (["-U", "-n", "-B1", "-A1", "-r", "X", "start\nmiddle", Path]);
         Newline_Matches : constant Run_Outcome := Run_Rg (["-U", "-n", "-r", "X", "\n", Path]);
      begin
         AUnit.Assertions.Assert
           (Numbered.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Numbered.Output) = "4:middle-start" & LF,
            "numbered captures expand in replacement output");
         AUnit.Assertions.Assert
           (To_String (Named.Output) = "4:<start/middle>" & LF,
            "ripgrep named capture syntax and references are supported");
         AUnit.Assertions.Assert
           (To_String (Multiple.Output) =
              "2:<start/>" & LF & "3:</middle>" & LF & "4:<start/> </middle>" & LF,
            "numbered captures span the ordered pattern set");
         AUnit.Assertions.Assert
           (To_String (Dollars.Output) = "2:$" & LF & "4:$ middle" & LF
            and then To_String (Unknown.Output) = "2:<>" & LF & "4:<> middle" & LF,
            "literal dollars and unknown captures follow ripgrep replacement grammar");
         AUnit.Assertions.Assert
           (To_String (Match_Only.Output) = "4:middle-start" & LF,
            "match-only replacement emits just the expanded template");
         AUnit.Assertions.Assert
           (To_String (Context.Output) =
              "1-zero" & LF & "2:X" & LF & "3-middle" & LF & "4:X middle" & LF,
            "selected context records are replaced while context records remain unchanged");
         AUnit.Assertions.Assert
           (To_String (Inverted.Output) = "1:zero" & LF & "3:middle" & LF
            and then To_String (Counted.Output) = "2" & LF,
            "replacement does not alter inverted or count result modes");
         AUnit.Assertions.Assert
           (To_String (Empty.Output) = "2:" & LF & "4: middle" & LF,
            "an empty replacement is distinct from no replacement option");
         AUnit.Assertions.Assert
           (Duplicate.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains
              (To_String (Duplicate.Errors), "duplicate capture group name: x"),
            "duplicate capture names across patterns are rejected");
         AUnit.Assertions.Assert
           (To_String (Multiline.Output) = "2:middle/start" & LF
            and then To_String (Multiline_Context.Output) =
              "1-zero" & LF & "2:X" & LF & "4-start middle" & LF,
            "multiline replacements preserve captures and original context line numbers");
         AUnit.Assertions.Assert
           (Newline_Matches.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Newline_Matches.Output) =
              "1:zeroXstartXmiddleXstart middleX" & LF,
            "adjacent replaced line breaks merge into one transformed output record");
      end;

      Test_Support.Delete_If_Exists (Path);
   end Test_Replacement_Output;
end Rg_Replace_Tests;
