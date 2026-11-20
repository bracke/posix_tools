with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Terminal_Styles;
with Test_Contexts;
with Test_Support;

package body Rg_Color_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;
   use type Terminal_Styles.Color_Policy;

   type Run_Outcome is record
      Output : Unbounded_String;
      Errors : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Run_Rg
     (Args     : Posix_Tools.Arguments.Vector;
      Input    : String := "";
      Terminal : Boolean := False) return Run_Outcome;

   function Run_Rg
     (Args     : Posix_Tools.Arguments.Vector;
      Input    : String := "";
      Terminal : Boolean := False) return Run_Outcome
   is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Test_Contexts.Set_Standard_Input (Context, Input);
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, Terminal);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Color_Output (T : in out Fixture) is
      pragma Unreferenced (T);
      ESC  : constant Character := Character'Val (16#1B#);
      LF   : constant Character := ASCII.LF;
      Data : constant String := "before hit after hit" & LF & "no" & LF;
      Plain : constant Run_Outcome :=
        Run_Rg (["--color", "auto", "-N", "--no-heading", "-I", "hit", "-"], Data);
      Forced : constant Run_Outcome :=
        Run_Rg (["--color=always", "-N", "--no-heading", "-I", "hit", "-"], Data);
      Ansi : constant Run_Outcome :=
        Run_Rg (["--color", "ansi", "-N", "--no-heading", "-I", "hit", "-"], Data);
      Suppressed : constant Run_Outcome :=
        Run_Rg (["--color", "never", "-N", "--no-heading", "-I", "hit", "-"], Data, True);
      Automatic_Terminal : constant Run_Outcome :=
        Run_Rg (["--color", "auto", "-N", "--no-heading", "-I", "hit", "-"], Data, True);
      Match_Only : constant Run_Outcome :=
        Run_Rg (["--color", "always", "-N", "--no-heading", "-I", "-o", "hit", "-"], Data);
      Multiline : constant Run_Outcome :=
        Run_Rg
          (["--color", "always", "-N", "--no-heading", "-I", "-U", "hit\nafter", "-"],
           "hit" & LF & "after" & LF);
      Statistics : constant Run_Outcome :=
        Run_Rg
          (["--color", "always", "--stats", "-N", "--no-heading", "-I", "hit", "-"],
           Data);
      Custom_Match : constant Run_Outcome :=
        Run_Rg
          (["--color", "always", "--colors", "match:fg:blue", "--colors=match:style:underline",
            "-N", "--no-heading", "-I", "hit", "-"],
           Data);
      No_Match_Style : constant Run_Outcome :=
        Run_Rg
          (["--color", "always", "--colors", "match:none", "-N", "--no-heading", "-I", "hit", "-"],
           Data);
      Highlighted : constant Run_Outcome :=
        Run_Rg
          (["--color", "always", "--colors", "highlight:bg:yellow", "--colors",
            "highlight:fg:black", "-N", "--no-heading", "-I", "hit", "-"],
           Data);
      Extended : constant Run_Outcome :=
        Run_Rg
          (["--color", "always", "--colors", "match:fg:0,128,255", "-N", "-I", "hit", "-"],
           Data);
      Indexed : constant Run_Outcome :=
        Run_Rg
          (["--color", "always", "--colors", "match:fg:202", "--colors", "match:bg:17",
            "-N", "-I", "hit", "-"],
           Data);
      Bad_Extended : constant Run_Outcome :=
        Run_Rg (["--colors", "match:fg:256", "hit", "-"]);
      Huge_Extended : constant Run_Outcome :=
        Run_Rg (["--colors", "match:fg:999999999999999999999999999999999999", "hit", "-"]);
      Bad_Rule : constant Run_Outcome :=
        Run_Rg (["--colors", "match:style:blink", "hit", "-"]);
      Bad_Format : constant Run_Outcome := Run_Rg (["--colors", ":none", "hit", "-"]);
      Invalid : constant Run_Outcome := Run_Rg (["--color", "sometimes", "hit", "-"]);
      Automatic_Expected : constant Boolean := Terminal_Styles.Color_Enabled (True);
   begin
      AUnit.Assertions.Assert
        (Plain.Status = Posix_Tools.Exit_Status.Success
         and then To_String (Plain.Output) = "before hit after hit" & LF
         and then not Test_Support.Contains (To_String (Plain.Output), "" & ESC),
         "automatic color is disabled for redirected output");
      AUnit.Assertions.Assert
        (Forced.Status = Posix_Tools.Exit_Status.Success
         and then Test_Support.Contains (To_String (Forced.Output), "" & ESC)
         and then Test_Support.Contains (To_String (Forced.Output), "before ")
         and then Test_Support.Contains (To_String (Forced.Output), " after "),
         "forced color highlights match spans without replacing surrounding text");
      AUnit.Assertions.Assert
        (Test_Support.Contains (To_String (Ansi.Output), "" & ESC),
         "ansi is a force-color alias");
      AUnit.Assertions.Assert
        (To_String (Suppressed.Output) = "before hit after hit" & LF
         and then not Test_Support.Contains (To_String (Suppressed.Output), "" & ESC),
         "never suppresses color on a terminal");
      AUnit.Assertions.Assert
        (Test_Support.Contains (To_String (Automatic_Terminal.Output), "" & ESC)
         = Automatic_Expected,
         "automatic color follows terminal and NO_COLOR policy");
      AUnit.Assertions.Assert
        (Test_Support.Contains (To_String (Match_Only.Output), "" & ESC)
         and then Test_Support.Contains (To_String (Multiline.Output), "" & ESC),
         "match-only and multiline results retain match highlighting");
      AUnit.Assertions.Assert
        (Test_Support.Contains (To_String (Statistics.Output), "21 bytes printed" & LF),
         "statistics exclude ANSI control sequences from printed-byte totals");
      AUnit.Assertions.Assert
        (Test_Support.Contains (To_String (Custom_Match.Output), "" & ESC)
         and then Test_Support.Contains (To_String (Custom_Match.Output), "hit"),
         "repeated custom match color and style rules compose");
      AUnit.Assertions.Assert
        (To_String (No_Match_Style.Output) = "before hit after hit" & LF,
         "the none rule clears all styling for its output role");
      AUnit.Assertions.Assert
        (Test_Support.Contains (To_String (Highlighted.Output), "" & ESC)
         and then Test_Support.Contains (To_String (Highlighted.Output), "before ")
         and then Test_Support.Contains (To_String (Highlighted.Output), " after "),
         "highlight rules style non-matching portions of selected lines");
      AUnit.Assertions.Assert
        (Extended.Status = Posix_Tools.Exit_Status.Success
         and then Test_Support.Contains
           (To_String (Extended.Output), ESC & "[38;2;0;128;255m"),
         "RGB custom colors use truecolor SGR output");
      AUnit.Assertions.Assert
        (Indexed.Status = Posix_Tools.Exit_Status.Success
         and then Test_Support.Contains (To_String (Indexed.Output), ESC & "[38;5;202m")
         and then Test_Support.Contains (To_String (Indexed.Output), ESC & "[48;5;17m"),
         "indexed custom foreground and background colors use 256-color SGR output");
      AUnit.Assertions.Assert
        (Bad_Extended.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Support.Contains
           (To_String (Bad_Extended.Errors), "unrecognized color value"),
         "out-of-range extended colors are rejected explicitly");
      AUnit.Assertions.Assert
        (Huge_Extended.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Support.Contains
           (To_String (Huge_Extended.Errors), "unrecognized color value"),
         "oversized extended colors are rejected without numeric overflow");
      AUnit.Assertions.Assert
        (Bad_Rule.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Support.Contains (To_String (Bad_Rule.Errors), "unrecognized color style"),
         "invalid custom color rules are rejected");
      AUnit.Assertions.Assert
        (Bad_Format.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Support.Contains (To_String (Bad_Format.Errors), "invalid color specification"),
         "malformed custom color rules are rejected without an internal error");
      AUnit.Assertions.Assert
        (Invalid.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Support.Contains (To_String (Invalid.Errors), "invalid value for --color"),
         "invalid color policies are rejected");

      Terminal_Styles.Set_Color_Policy (Terminal_Styles.Color_Never);
      declare
         Ignored : constant Run_Outcome :=
           Run_Rg (["--color", "always", "-N", "--no-heading", "-I", "hit", "-"], "hit" & LF);
      begin
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Ignored.Output), "" & ESC),
            "forced command color does not depend on the shared automatic policy");
      end;
      AUnit.Assertions.Assert
        (Terminal_Styles.Current_Color_Policy = Terminal_Styles.Color_Never,
         "rg does not alter the shared terminal style policy while rendering");
      Terminal_Styles.Set_Color_Policy (Terminal_Styles.Color_Auto);
   end Test_Color_Output;
end Rg_Color_Tests;
