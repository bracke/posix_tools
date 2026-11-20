with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Test_Contexts;

package body Rg_Unicode_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;

   type Run_Outcome is record
      Output : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Run_Rg
     (Args  : Posix_Tools.Arguments.Vector;
      Input : String) return Run_Outcome
   is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Test_Contexts.Set_Standard_Input (Context, Input);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Unicode_Case (T : in out Fixture) is
      pragma Unreferenced (T);
      LF          : constant Character := ASCII.LF;
      Greek_Upper : constant String := Character'Val (16#CE#) & Character'Val (16#91#);
      Greek_Lower : constant String := Character'Val (16#CE#) & Character'Val (16#B1#);
      Kelvin      : constant String :=
        Character'Val (16#E2#) & Character'Val (16#84#) & Character'Val (16#AA#);
      Sharp_S     : constant String := Character'Val (16#C3#) & Character'Val (16#9F#);
      Insensitive : constant Run_Outcome :=
        Run_Rg (["-i", Greek_Upper], Greek_Lower & LF);
      Smart_Lower : constant Run_Outcome :=
        Run_Rg (["-S", Greek_Lower], Greek_Upper & LF & Greek_Lower & LF);
      Smart_Upper : constant Run_Outcome :=
        Run_Rg (["-S", Greek_Upper], Greek_Lower & LF & Greek_Upper & LF);
      Literal : constant Run_Outcome :=
        Run_Rg (["-F", "-i", "K"], Kelvin & LF);
      Class_Result : constant Run_Outcome :=
        Run_Rg (["-i", "[K]"], Kelvin & LF);
      Simple_Only : constant Run_Outcome :=
        Run_Rg (["-i", "ss"], Sharp_S & LF);
   begin
      AUnit.Assertions.Assert
        (To_String (Insensitive.Output) = Greek_Lower & LF,
         "Unicode-insensitive search folds Greek letters");
      AUnit.Assertions.Assert
        (To_String (Smart_Lower.Output) = Greek_Upper & LF & Greek_Lower & LF,
         "smart case treats a Unicode lowercase pattern as insensitive");
      AUnit.Assertions.Assert
        (To_String (Smart_Upper.Output) = Greek_Upper & LF,
         "smart case detects a Unicode uppercase pattern");
      AUnit.Assertions.Assert
        (To_String (Literal.Output) = Kelvin & LF,
         "fixed-string insensitive search uses Unicode simple folding");
      AUnit.Assertions.Assert
        (To_String (Class_Result.Output) = Kelvin & LF,
         "character classes use Unicode simple folding");
      AUnit.Assertions.Assert
        (Simple_Only.Status = Posix_Tools.Commands.Rg.No_Matches,
         "Unicode case matching remains simple and does not expand sharp-s to ss");

      declare
         Grinning : constant String :=
           Character'Val (16#F0#) & Character'Val (16#9F#)
           & Character'Val (16#98#) & Character'Val (16#80#);
         Word_Result : constant Run_Outcome :=
           Run_Rg (["-w", Greek_Lower], "x" & Greek_Lower & "x" & LF & Greek_Lower & LF);
         Script_Result : constant Run_Outcome :=
           Run_Rg (["-o", "\p{Greek}+"], "abc " & Greek_Upper & Greek_Lower & LF);
         Emoji_Result : constant Run_Outcome :=
           Run_Rg (["-o", "\p{Emoji}"], "plain " & Grinning & LF);
      begin
         AUnit.Assertions.Assert
           (Word_Result.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Word_Result.Output) = Greek_Lower & LF,
            "whole-word matching uses Unicode word classification");
         AUnit.Assertions.Assert
           (Script_Result.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Script_Result.Output) = Greek_Upper & Greek_Lower & LF,
            "script properties are available through the rg adapter");
         AUnit.Assertions.Assert
           (Emoji_Result.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Emoji_Result.Output) = Grinning & LF,
            "binary Unicode properties are available through the rg adapter");
      end;

      declare
         Invalid : constant Character := Character'Val (16#FF#);
         Whole_Word : constant Run_Outcome :=
           Run_Rg (["-w", "hit"], "pre" & Invalid & "hit" & LF & "plain hit" & LF);
         Dot : constant Run_Outcome := Run_Rg (["-o", "."], "A" & Invalid & "B" & LF);
         Words : constant Run_Outcome :=
           Run_Rg (["-o", "\w+"], "pre" & Invalid & "hit" & LF);
         Bytes : constant Run_Outcome :=
           Run_Rg (["-o", "(?-u:.)"], "A" & Invalid & "B" & LF);
         Mixed : constant Run_Outcome :=
           Run_Rg (["-o", "A(?-u:.)(?u:B)"], "A" & Invalid & "B" & LF);
      begin
         AUnit.Assertions.Assert
           (Whole_Word.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Whole_Word.Output) = "plain hit" & LF,
            "invalid UTF-8 does not create a synthetic whole-word boundary");
         AUnit.Assertions.Assert
           (Dot.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Dot.Output) = "A" & LF & "B" & LF,
            "Unicode dot skips invalid UTF-8 bytes and resumes searching");
         AUnit.Assertions.Assert
           (Words.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Words.Output) = "pre" & LF & "hit" & LF,
            "Unicode matching resumes after invalid UTF-8 bytes");
         AUnit.Assertions.Assert
           (Bytes.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Bytes.Output) =
              "A" & LF & Invalid & LF & "B" & LF,
            "an outer (?-u:...) group selects arbitrary bytes like ripgrep");
         AUnit.Assertions.Assert
           (Mixed.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Mixed.Output) = "A" & Invalid & "B" & LF,
            "nested byte and Unicode mode groups retain ripgrep byte offsets");
      end;
   end Test_Unicode_Case;
end Rg_Unicode_Tests;
