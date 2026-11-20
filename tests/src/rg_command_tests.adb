with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Commands.Rg.Ignore;
with Posix_Tools.Commands.Rg.Options;
with Posix_Tools.Commands.Rg.Patterns;
with Posix_Tools.Commands.Rg.Rendering;
with Posix_Tools.Exit_Status;
with Regexp;
with Test_Contexts;
with Test_Support;
with Version.Ignore;

package body Rg_Command_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;
   use type Posix_Tools.Commands.Rg.Patterns.Pattern_Status;
   use type Posix_Tools.Commands.Rg.Options.Parse_Outcome;
   use type Posix_Tools.Commands.Rg.Patterns.Case_Mode;
   use type Posix_Tools.Commands.Rg.Rendering.Result_Mode;
   use type Regexp.Compile_Status;
   use type Regexp.Match_Status;
   use type Regexp.Policy_Feature;
   use type Version.Ignore.Match_Reason;
   use type Version.Ignore.Rule_Source_Kind;

   package Patterns renames Posix_Tools.Commands.Rg.Patterns;
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

   procedure Test_Default_Syntax_Policy (T : in out Fixture) is
      pragma Unreferenced (T);

      procedure Check_Rejected (Source : String; Feature : Regexp.Policy_Feature);

      procedure Check_Rejected (Source : String; Feature : Regexp.Policy_Feature) is
         Pattern    : Patterns.Compiled_Pattern;
         Diagnostic : Patterns.Compile_Diagnostic;
      begin
         Patterns.Compile (Source, (others => <>), Pattern, Diagnostic);
         AUnit.Assertions.Assert
           (Diagnostic.Status = Patterns.Pattern_Disallowed
            and then Diagnostic.Feature = Feature
            and then not Patterns.Is_Valid (Pattern),
            "default syntax rejects " & Source);
      end Check_Rejected;

      Pattern    : Patterns.Compiled_Pattern;
      Diagnostic : Patterns.Compile_Diagnostic;
   begin
      Check_Rejected ("(a)\1", Regexp.Policy_Feature_Backreferences);
      Check_Rejected ("a(?=b)", Regexp.Policy_Feature_Lookaround);
      Check_Rejected ("(?>a)", Regexp.Policy_Feature_Atomic);
      Check_Rejected ("a++", Regexp.Policy_Feature_Atomic);

      Patterns.Compile ("(ab|cd)+?", (others => <>), Pattern, Diagnostic);
      AUnit.Assertions.Assert
        (Diagnostic.Status = Patterns.Pattern_Ok and then Patterns.Is_Valid (Pattern),
         "ordinary captures, alternation, and lazy repetition remain available");
   end Test_Default_Syntax_Policy;

   procedure Test_Help_And_Version (T : in out Fixture) is
      pragma Unreferenced (T);
      Help       : constant Run_Outcome := Run_Rg (["--help"]);
      Version    : constant Run_Outcome := Run_Rg (["--version"]);
      No_Match   : constant Run_Outcome := Run_Rg (["needle"]);
      Invalid    : constant Run_Outcome := Run_Rg (["["]);
      Disallowed : constant Run_Outcome := Run_Rg (["a(?=b)"]);
   begin
      AUnit.Assertions.Assert
        (Help.Status = Posix_Tools.Exit_Status.Success
         and then Test_Support.Contains (To_String (Help.Output), "Usage: rg")
         and then Test_Support.Contains (To_String (Help.Output), "--count-matches")
         and then Test_Support.Contains (To_String (Help.Output), "-g GLOB")
         and then Test_Support.Contains (To_String (Help.Output), "-f FILE")
         and then Test_Support.Contains (To_String (Help.Output), "--type-list")
         and then Test_Support.Contains (To_String (Help.Output), "--debug")
         and then Test_Support.Contains (To_String (Help.Output), "--context-separator")
         and then Test_Support.Contains (To_String (Help.Output), "-o"),
         "rg help succeeds");
      AUnit.Assertions.Assert
        (Version.Status = Posix_Tools.Exit_Status.Success
         and then Test_Support.Contains (To_String (Version.Output), "engine regexp"),
         "rg version identifies its engine");
      AUnit.Assertions.Assert
        (No_Match.Status = Posix_Tools.Commands.Rg.No_Matches
         and then To_String (No_Match.Output) = ""
         and then To_String (No_Match.Errors) = "",
         "an empty input reports no matches");
      AUnit.Assertions.Assert
        (Invalid.Status = Posix_Tools.Commands.Rg.Trouble
         and then Test_Support.Contains (To_String (Invalid.Errors), "invalid pattern")
         and then Test_Support.Contains (To_String (Invalid.Errors), "UNTERMINATED_CLASS"),
         "invalid regex diagnostics retain the engine status");
      AUnit.Assertions.Assert
        (Disallowed.Status = Posix_Tools.Commands.Rg.Trouble
         and then Test_Support.Contains (To_String (Disallowed.Errors), "not supported")
         and then Test_Support.Contains (To_String (Disallowed.Errors), "LOOKAROUND"),
         "default-mode policy failures are explicit");
   end Test_Help_And_Version;

   procedure Test_Option_Parsing (T : in out Fixture) is
      pragma Unreferenced (T);
      package Options renames Posix_Tools.Commands.Rg.Options;

      Context : Test_Contexts.Capturing_Context;
      Config  : Options.Invocation;
      Outcome : Options.Parse_Outcome;
   begin
      Context.Initialize ("rg", ["-Fiwx", "-efoo", "-e", "Bar", "path"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Search_Ready
         and then Options.Pattern_Count (Config) = 2
         and then Options.Pattern (Config, 1) = "foo"
         and then Options.Pattern (Config, 2) = "Bar"
         and then Options.Path_Count (Config) = 1
         and then Options.Path (Config, 1) = "path"
         and then Options.Fixed_Strings (Config)
         and then Options.Whole_Word (Config)
         and then Options.Whole_Line (Config)
         and then not Options.Include_Hidden (Config)
         and then Options.Use_Ignore_Files (Config)
         and then Options.Max_Depth (Config) = Natural'Last
         and then Options.Case_Handling (Config) = Patterns.Insensitive,
         "combined options, repeated patterns, and explicit paths parse deterministically");

      Context.Initialize ("rg", ["-S", "lower"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Options.Case_Handling (Config) = Patterns.Insensitive,
         "smart case folds lowercase patterns");

      Context.Initialize ("rg", ["-S", "Upper"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Options.Case_Handling (Config) = Patterns.Sensitive,
         "smart case preserves uppercase patterns");

      Context.Initialize ("rg", ["--", "-needle", "path"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Search_Ready
         and then Options.Pattern (Config, 1) = "-needle"
         and then Options.Path (Config, 1) = "path",
         "end-of-options preserves option-shaped operands");

      Context.Initialize ("rg", ["--unknown", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Parse_Error
         and then Test_Support.Contains (Options.Diagnostic (Config), "unknown option"),
         "unknown long options are rejected");

      Context.Initialize ("rg", ["-e"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Parse_Error
         and then Test_Support.Contains (Options.Diagnostic (Config), "requires an argument"),
         "a missing option value is rejected");

      Context.Initialize ("rg", ["--hidden", "--no-ignore", "--max-depth=12", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Search_Ready and then Options.Include_Hidden (Config)
         and then not Options.Use_Ignore_Files (Config)
         and then Options.Max_Depth (Config) = 12,
         "traversal options retain their exact values");

      Context.Initialize ("rg", ["-uu", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Search_Ready
         and then Options.Include_Hidden (Config)
         and then not Options.Use_Ignore_Files (Config),
         "-uu disables ignore rules and includes hidden paths");
      Context.Initialize ("rg", ["-uuu", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Search_Ready
         and then Options.Include_Hidden (Config)
         and then not Options.Use_Ignore_Files (Config),
         "-uuu disables ignore rules and includes hidden paths before binary search");
      Context.Initialize ("rg", ["--no-ignore-vcs", "--no-ignore-parent", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Search_Ready
         and then not Options.Use_Vcs_Ignore (Config)
         and then not Options.Use_Parent_Ignore (Config),
         "independent ignore source controls retain their values");
      Context.Initialize ("rg", ["--max-depth", "invalid", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Parse_Error
         and then Test_Support.Contains (Options.Diagnostic (Config), "invalid value"),
         "an invalid maximum depth is rejected");
      Context.Initialize ("rg", ["-nHI", "--column", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Search_Ready
         and then Options.Line_Numbers (Config, Output_Is_Terminal => False)
         and then Options.Columns (Config)
         and then not Options.Prefix_Filename (Config, Automatic_Value => True),
         "line, column, and filename rendering options preserve short-option precedence");
      Context.Initialize ("rg", ["-nN", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (not Options.Line_Numbers (Config, Output_Is_Terminal => True),
         "-N suppresses even terminal-default line numbers");
      Context.Initialize ("rg", ["-vm2", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Search_Ready
         and then Options.Invert_Match (Config)
         and then Options.Max_Count (Config) = 2,
         "inversion and an attached maximum count parse in a short-option group");
      Context.Initialize ("rg", ["--max-count", "-1", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Parse_Error
         and then Test_Support.Contains (Options.Diagnostic (Config), "invalid value"),
         "a negative maximum count is rejected");
      Context.Initialize ("rg", ["-lc", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Options.Mode (Config) = Posix_Tools.Commands.Rg.Rendering.Count_Lines,
         "the last non-quiet result mode wins");
      Context.Initialize ("rg", ["-qcl", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Options.Mode (Config) = Posix_Tools.Commands.Rg.Rendering.Quiet,
         "quiet mode dominates later result modes");
      Context.Initialize ("rg", ["-oc", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Options.Mode (Config) = Posix_Tools.Commands.Rg.Rendering.Count_Matches,
         "-o changes selected-line count mode into match-count mode");
      Context.Initialize ("rg", ["--count-matches", "-c", "x"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Options.Mode (Config) = Posix_Tools.Commands.Rg.Rendering.Count_Lines,
         "a later -c restores selected-line counting");
      Context.Initialize ("rg", Posix_Tools.Arguments.Empty);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Parse_Error
         and then Test_Support.Contains (Options.Diagnostic (Config), "pattern is required"),
         "a missing pattern is rejected");

      Context.Initialize ("rg", ["--files", "path"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Search_Ready
         and then Options.Files_Only (Config)
         and then Options.Pattern_Count (Config) = 0
         and then Options.Path_Count (Config) = 1
         and then Options.Path (Config, 1) = "path",
         "--files treats every operand as a search path and needs no pattern");

      Context.Initialize ("rg", ["--files", "-e", "unused", "-f", "missing", "path"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Search_Ready
         and then Options.Pattern_Count (Config) = 0
         and then Options.Path_Count (Config) = 1
         and then Options.Path (Config, 1) = "path",
         "--files ignores pattern sources without reading them");

      Context.Initialize ("rg", ["--files", "-g*.adb", "--glob", "!src/**", "path"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Search_Ready
         and then Options.Glob_Count (Config) = 2
         and then Options.Glob (Config, 1) = "*.adb"
         and then Options.Glob (Config, 2) = "!src/**",
         "short attached and long separate glob options preserve rule order");

      Context.Initialize ("rg", ["--files", "-c"]);
      Options.Parse (Context, Config, Outcome);
      AUnit.Assertions.Assert
        (Outcome = Options.Parse_Error
         and then Test_Support.Contains (Options.Diagnostic (Config), "cannot be combined"),
         "--files rejects search result modes instead of silently changing their meaning");
   end Test_Option_Parsing;

   procedure Test_Sequential_Search (T : in out Fixture) is
      pragma Unreferenced (T);
      LF     : constant Character := ASCII.LF;
      CR     : constant Character := ASCII.CR;
      First  : constant String := Test_Support.Work_Path ("rg-first.txt");
      Second : constant String := Test_Support.Work_Path ("rg-second.txt");
   begin
      declare
         Found : constant Run_Outcome :=
           Run_Rg (["needle"], "before" & LF & "needle here" & LF & "after" & LF);
         Absent : constant Run_Outcome := Run_Rg (["missing"], "text" & LF);
      begin
         AUnit.Assertions.Assert
           (Found.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Found.Output) = "needle here" & LF
            and then To_String (Found.Errors) = "",
            "standard input emits selected lines and succeeds");
         AUnit.Assertions.Assert
           (Absent.Status = Posix_Tools.Commands.Rg.No_Matches
            and then To_String (Absent.Output) = "",
            "standard input without a match returns status one");
      end;

      declare
         Modes : constant Run_Outcome :=
           Run_Rg (["-i", "-w", "ada"], "an ADA tool" & LF & "canada" & LF);
         Fixed : constant Run_Outcome :=
           Run_Rg (["-F", "."], "abc" & LF & "a.b" & LF);
         Whole : constant Run_Outcome :=
           Run_Rg (["-x", "line"], "line" & LF & "line suffix" & LF);
         Smart : constant Run_Outcome :=
           Run_Rg (["-S", "Ada"], "ada" & LF & "Ada" & LF);
      begin
         AUnit.Assertions.Assert
           (To_String (Modes.Output) = "an ADA tool" & LF, "case-insensitive whole-word search");
         AUnit.Assertions.Assert
           (To_String (Fixed.Output) = "a.b" & LF, "fixed-string search");
         AUnit.Assertions.Assert
           (To_String (Whole.Output) = "line" & LF, "whole-line search");
         AUnit.Assertions.Assert
           (To_String (Smart.Output) = "Ada" & LF, "smart case with uppercase is sensitive");
      end;

      declare
         Multiple : constant Run_Outcome :=
           Run_Rg (["-e", "alpha", "-e", "beta"], "beta" & LF & "none" & LF & "alpha" & LF);
         Empty : constant Run_Outcome := Run_Rg ([""], "one" & LF & LF);
         Endings : constant Run_Outcome := Run_Rg (["needle"], "needle" & CR & LF & "needle");
      begin
         AUnit.Assertions.Assert
           (To_String (Multiple.Output) = "beta" & LF & "alpha" & LF,
            "multiple patterns select in input order");
         AUnit.Assertions.Assert
           (To_String (Empty.Output) = "one" & LF & LF, "an empty pattern selects empty and nonempty lines");
         AUnit.Assertions.Assert
           (To_String (Endings.Output) = "needle" & CR & LF & "needle" & LF,
            "CRLF is preserved and an unterminated final match gains LF");
      end;

      Test_Support.Write_File (First, "alpha" & LF & "none" & LF);
      Test_Support.Write_File (Second, "beta" & LF);
      declare
         One  : constant Run_Outcome := Run_Rg (["alpha", First]);
         Many : constant Run_Outcome := Run_Rg (["-e", "alpha", "-e", "beta", First, Second]);
         Missing : constant Run_Outcome :=
           Run_Rg (["x", Test_Support.Work_Path ("rg-missing.txt")]);
      begin
         AUnit.Assertions.Assert
           (One.Status = Posix_Tools.Exit_Status.Success
            and then To_String (One.Output) = "alpha" & LF,
            "one explicit file is searched without a name prefix");
         AUnit.Assertions.Assert
           (Many.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Many.Output) = First & ":alpha" & LF & Second & ":beta" & LF,
            "multiple explicit files receive name prefixes");
         AUnit.Assertions.Assert
           (Missing.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains (To_String (Missing.Errors), "cannot read"),
            "a missing explicit file is trouble");
      end;

      declare
         Context : Test_Contexts.Capturing_Context;
         Result  : Posix_Tools.Commands.Results.Result;
         Input   : constant String :=
           "needle" & LF & "needle" & LF & "needle" & LF
           & "needle" & LF & "needle" & LF & "needle" & LF;
      begin
         Context.Initialize ("rg", ["needle"]);
         Test_Contexts.Set_Standard_Input (Context, Input);
         Test_Contexts.Set_Output_Failure_After (Context, 32);
         Posix_Tools.Commands.Rg.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains
              (Test_Contexts.Error_Output (Context), "cannot write standard output"),
            "a broken standard output cancels the search and returns trouble");
      end;
      Test_Support.Delete_If_Exists (First);
      Test_Support.Delete_If_Exists (Second);
   end Test_Sequential_Search;

   procedure Test_Pattern_Files (T : in out Fixture) is
      pragma Unreferenced (T);
      LF       : constant Character := ASCII.LF;
      CR       : constant Character := ASCII.CR;
      Data     : constant String := Test_Support.Work_Path ("rg-pattern-data.txt");
      Patterns : constant String := Test_Support.Work_Path ("rg-patterns.txt");
      Empty    : constant String := Test_Support.Work_Path ("rg-patterns-empty.txt");
      Blank    : constant String := Test_Support.Work_Path ("rg-patterns-blank.txt");
      CRLF     : constant String := Test_Support.Work_Path ("rg-patterns-crlf.txt");
      Order    : constant String := Test_Support.Work_Path ("rg-patterns-order.txt");
      Missing  : constant String := Test_Support.Work_Path ("rg-patterns-missing.txt");
   begin
      Test_Support.Write_File (Data, "alpha" & LF & "beta" & LF & "none" & LF & "name" & LF);
      Test_Support.Write_File (Patterns, "alpha" & LF & "beta" & LF);
      Test_Support.Write_File (Empty, "");
      Test_Support.Write_File (Blank, "absent" & LF & LF);
      Test_Support.Write_File (CRLF, "alpha" & CR & LF);
      Test_Support.Write_File (Order, "name" & LF);
      Test_Support.Delete_If_Exists (Missing);

      declare
         Loaded   : constant Run_Outcome := Run_Rg (["-f", Patterns, Data]);
         Long     : constant Run_Outcome := Run_Rg (["--file=" & CRLF, Data]);
         No_Rules : constant Run_Outcome := Run_Rg (["-f", Empty, Data]);
         Inverted : constant Run_Outcome := Run_Rg (["-v", "-f", Empty, Data]);
         Empty_Rule : constant Run_Outcome := Run_Rg (["-f", Blank, Data]);
      begin
         AUnit.Assertions.Assert
           (Loaded.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Loaded.Output) = "alpha" & LF & "beta" & LF,
            "-f loads one pattern per line");
         AUnit.Assertions.Assert
           (To_String (Long.Output) = "alpha" & LF,
            "--file= accepts a path and strips CR from CRLF pattern records");
         AUnit.Assertions.Assert
           (No_Rules.Status = Posix_Tools.Commands.Rg.No_Matches
            and then To_String (No_Rules.Output) = "",
            "an empty pattern file supplies no patterns");
         AUnit.Assertions.Assert
           (To_String (Inverted.Output) =
              "alpha" & LF & "beta" & LF & "none" & LF & "name" & LF,
            "inverting an empty pattern set selects every line");
         AUnit.Assertions.Assert
           (To_String (Empty_Rule.Output) =
              "alpha" & LF & "beta" & LF & "none" & LF & "name" & LF,
            "a blank record in a pattern file is an empty pattern");
      end;

      declare
         File_First : constant Run_Outcome :=
           Run_Rg (["-o", "-f", Order, "-e", "nam", Data]);
         Inline_First : constant Run_Outcome :=
           Run_Rg (["-o", "-e", "nam", "-f", Order, Data]);
         From_Stdin : constant Run_Outcome := Run_Rg (["-f", "-", Data], "beta" & LF);
         Conflict : constant Run_Outcome := Run_Rg (["-f", "-", "-"], "alpha" & LF);
         Not_Found : constant Run_Outcome := Run_Rg (["-f", Missing, Data]);
         Listing : constant Run_Outcome := Run_Rg (["--files", "-f", Missing, Data]);
      begin
         AUnit.Assertions.Assert
           (To_String (File_First.Output) = "name" & LF
            and then To_String (Inline_First.Output) = "nam" & LF,
            "interleaved -e and -f sources preserve pattern order");
         AUnit.Assertions.Assert
           (To_String (From_Stdin.Output) = "beta" & LF,
            "-f - reads patterns from standard input before searching an explicit file");
         AUnit.Assertions.Assert
           (Conflict.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains (To_String (Conflict.Errors), "both patterns and search data"),
            "standard input cannot be both a pattern source and a search path");
         AUnit.Assertions.Assert
           (Not_Found.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains (To_String (Not_Found.Errors), "cannot read pattern file"),
            "a missing pattern file is a parse-time error");
         AUnit.Assertions.Assert
           (Listing.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Listing.Output) = Data & LF,
            "--files ignores pattern files instead of opening them");
      end;

      Test_Support.Delete_If_Exists (Data);
      Test_Support.Delete_If_Exists (Patterns);
      Test_Support.Delete_If_Exists (Empty);
      Test_Support.Delete_If_Exists (Blank);
      Test_Support.Delete_If_Exists (CRLF);
      Test_Support.Delete_If_Exists (Order);
   end Test_Pattern_Files;

   procedure Test_Ignore_Policy (T : in out Fixture) is
      pragma Unreferenced (T);
      package Ignore renames Posix_Tools.Commands.Rg.Ignore;

      LF        : constant Character := ASCII.LF;
      Root      : constant String := Test_Support.Work_Path ("rg-ignore");
      Sub       : constant String := Root & "/sub";
      Policy    : Ignore.Policy;
      Loaded    : Ignore.Load_Outcome;
      Other     : Ignore.Decision;
      Keep      : Ignore.Decision;
      Rg_Keep   : Ignore.Decision;
      Build     : Ignore.Decision;
      Child     : Ignore.Decision;
      Nested    : Ignore.Decision;
   begin
      Test_Support.Delete_If_Exists (Root);
      Ada.Directories.Create_Path (Sub);
      Test_Support.Write_File (Root & "/.gitignore", "*.tmp" & LF & "build/" & LF);
      Test_Support.Write_File (Root & "/.ignore", "!keep.tmp" & LF);
      Test_Support.Write_File (Root & "/.rgignore", "!rg-keep.tmp" & LF);
      Test_Support.Write_File (Sub & "/.gitignore", "!nested.tmp" & LF);

      Ignore.Initialize (Policy, Root, Use_Parent => False);
      Ignore.Enter_Directory (Policy, Root, "", Loaded);
      Other := Ignore.Evaluate (Policy, "other.tmp", False);
      Keep := Ignore.Evaluate (Policy, "keep.tmp", False);
      Rg_Keep := Ignore.Evaluate (Policy, "rg-keep.tmp", False);
      Build := Ignore.Evaluate (Policy, "build", True);
      Child := Ignore.Evaluate (Policy, "build/child.adb", False);

      AUnit.Assertions.Assert
        (not Loaded.Had_Error and then Loaded.Sources_Loaded = 3 and then Loaded.Rules_Added = 4,
         "all root ignore sources are loaded through Version.Ignore");
      AUnit.Assertions.Assert
        (Other.Is_Ignored
         and then Other.Match.Source_Kind = Version.Ignore.Gitignore_Source
         and then To_String (Other.Match.Pattern) = "*.tmp",
         "gitignore exclusion retains source provenance");
      AUnit.Assertions.Assert
        (not Keep.Is_Ignored
         and then Keep.Match.Has_Match
         and then Keep.Match.Source_Kind = Version.Ignore.Ignore_Source
         and then To_String (Keep.Match.Pattern) = "!keep.tmp",
         ".ignore has explicit precedence over .gitignore");
      AUnit.Assertions.Assert
        (not Rg_Keep.Is_Ignored
         and then Rg_Keep.Match.Source_Kind = Version.Ignore.Rgignore_Source,
         ".rgignore has the highest source precedence");
      AUnit.Assertions.Assert
        (Build.Is_Ignored
         and then Child.Is_Ignored
         and then Child.Match.Reason = Version.Ignore.Ignored_Parent,
         "excluded directories keep their descendants excluded");

      Ignore.Enter_Directory (Policy, Sub, "sub", Loaded);
      Nested := Ignore.Evaluate (Policy, "sub/nested.tmp", False);
      AUnit.Assertions.Assert
        (not Loaded.Had_Error
         and then Loaded.Sources_Loaded = 1
         and then not Nested.Is_Ignored
         and then Nested.Match.Source_Kind = Version.Ignore.Gitignore_Source
         and then To_String (Nested.Match.Base_Dir) = "sub"
         and then Test_Support.Contains
           (To_String (Nested.Match.Source_Path), "sub/.gitignore"),
         "nested ignore rules are scoped and retain their originating directory");
      Test_Support.Delete_If_Exists (Root);
   end Test_Ignore_Policy;

   procedure Test_Ignore_Controls (T : in out Fixture) is
      pragma Unreferenced (T);
      LF      : constant Character := ASCII.LF;
      Root    : constant String := Test_Support.Work_Path ("rg-ignore-controls");
      Search  : constant String := Root & "/search";
      Vcs     : constant String := Search & "/vcs.txt";
      Generic_File : constant String := Search & "/generic.txt";
      Rg_File : constant String := Search & "/rg.txt";
      Local   : constant String := Search & "/local.txt";
      Visible : constant String := Search & "/visible.txt";
      Hidden  : constant String := Search & "/.hidden.txt";
   begin
      Test_Support.Delete_If_Exists (Root);
      Ada.Directories.Create_Path (Search);
      Test_Support.Write_File (Root & "/.gitignore", "search/" & LF & "search/vcs.txt" & LF);
      Test_Support.Write_File (Root & "/.ignore", "search/generic.txt" & LF);
      Test_Support.Write_File (Root & "/.rgignore", "search/rg.txt" & LF);
      Test_Support.Write_File (Search & "/.gitignore", "local.txt" & LF);
      Test_Support.Write_File (Vcs, "needle vcs" & LF);
      Test_Support.Write_File (Generic_File, "needle generic" & LF);
      Test_Support.Write_File (Rg_File, "needle rg" & LF);
      Test_Support.Write_File (Local, "needle local" & LF);
      Test_Support.Write_File (Visible, "needle visible" & LF);
      Test_Support.Write_File (Hidden, "needle hidden" & LF);
      declare
         Default : constant Run_Outcome := Run_Rg (["needle", Search]);
         No_Vcs : constant Run_Outcome :=
           Run_Rg (["--no-ignore-vcs", "needle", Search]);
         No_Parent : constant Run_Outcome :=
           Run_Rg (["--no-ignore-parent", "needle", Search]);
         No_Ignore : constant Run_Outcome := Run_Rg (["-u", "needle", Search]);
         Unrestricted : constant Run_Outcome := Run_Rg (["-uu", "needle", Search]);
      begin
         AUnit.Assertions.Assert
           (To_String (Default.Output) = Visible & ":needle visible" & LF,
            "parent and local ignore sources are active by default");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (No_Vcs.Output), Vcs & ":needle vcs" & LF)
            and then not Test_Support.Contains (To_String (No_Vcs.Output), Generic_File)
            and then not Test_Support.Contains (To_String (No_Vcs.Output), Rg_File)
            and then Test_Support.Contains (To_String (No_Vcs.Output), Local & ":needle local" & LF),
            "--no-ignore-vcs disables parent and local gitignore sources only");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (No_Parent.Output), Vcs & ":needle vcs" & LF)
            and then Test_Support.Contains
              (To_String (No_Parent.Output), Generic_File & ":needle generic" & LF)
            and then Test_Support.Contains (To_String (No_Parent.Output), Rg_File & ":needle rg" & LF)
            and then not Test_Support.Contains (To_String (No_Parent.Output), Local),
            "--no-ignore-parent skips ancestors while retaining the search root's ignore files");
         AUnit.Assertions.Assert
           (Test_Support.Occurrences (To_String (No_Ignore.Output), "needle") = 5
            and then not Test_Support.Contains (To_String (No_Ignore.Output), Hidden),
            "-u disables every ignore source without enabling hidden files");
         AUnit.Assertions.Assert
           (Test_Support.Occurrences (To_String (Unrestricted.Output), "needle") = 6
            and then Test_Support.Contains
              (To_String (Unrestricted.Output), Hidden & ":needle hidden" & LF),
            "-uu additionally includes hidden files");
      end;
      Test_Support.Delete_If_Exists (Root);
   end Test_Ignore_Controls;

   procedure Test_Recursive_Traversal (T : in out Fixture) is
      pragma Unreferenced (T);
      LF     : constant Character := ASCII.LF;
      Root   : constant String := Test_Support.Work_Path ("rg-tree");
      Nested : constant String := Root & "/nested";
   begin
      Test_Support.Delete_If_Exists (Root);
      Ada.Directories.Create_Path (Nested);
      Test_Support.Write_File (Root & "/.gitignore", "*.gen" & LF);
      Test_Support.Write_File (Root & "/.ignore", "!keep.gen" & LF);
      Test_Support.Write_File (Nested & "/.gitignore", "blocked.adb" & LF);
      Test_Support.Write_File (Root & "/visible.adb", "needle visible" & LF);
      Test_Support.Write_File (Root & "/.hidden.adb", "needle hidden" & LF);
      Test_Support.Write_File (Root & "/drop.gen", "needle ignored" & LF);
      Test_Support.Write_File (Root & "/keep.gen", "needle included" & LF);
      Test_Support.Write_File (Nested & "/hit.adb", "needle nested" & LF);
      Test_Support.Write_File (Nested & "/blocked.adb", "needle blocked" & LF);

      declare
         Default_Search : constant Run_Outcome := Run_Rg (["needle", Root]);
         Hidden_Search  : constant Run_Outcome := Run_Rg (["--hidden", "needle", Root]);
         Ignore_Off     : constant Run_Outcome := Run_Rg (["--no-ignore", "needle", Root]);
         No_Entries     : constant Run_Outcome := Run_Rg (["--max-depth", "0", "needle", Root]);
         Root_Only      : constant Run_Outcome := Run_Rg (["--max-depth", "1", "needle", Root]);
      begin
         AUnit.Assertions.Assert
           (Default_Search.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Occurrences (To_String (Default_Search.Output), "needle") = 3
            and then Test_Support.Contains (To_String (Default_Search.Output), Root & "/visible.adb:")
            and then Test_Support.Contains (To_String (Default_Search.Output), Root & "/keep.gen:")
            and then Test_Support.Contains (To_String (Default_Search.Output), Root & "/nested/hit.adb:")
            and then not Test_Support.Contains (To_String (Default_Search.Output), "hidden")
            and then not Test_Support.Contains (To_String (Default_Search.Output), "ignored")
            and then not Test_Support.Contains (To_String (Default_Search.Output), "blocked"),
            "recursive search applies hidden and hierarchical ignore policies");
         AUnit.Assertions.Assert
           (Test_Support.Occurrences (To_String (Hidden_Search.Output), "needle") = 4
            and then Test_Support.Contains (To_String (Hidden_Search.Output), ".hidden.adb:"),
            "--hidden includes hidden files without disabling ignore rules");
         AUnit.Assertions.Assert
           (Test_Support.Occurrences (To_String (Ignore_Off.Output), "needle") = 5
            and then Test_Support.Contains (To_String (Ignore_Off.Output), "drop.gen:")
            and then Test_Support.Contains (To_String (Ignore_Off.Output), "blocked.adb:"),
            "--no-ignore disables all ignore-file sources without including hidden files");
         AUnit.Assertions.Assert
           (No_Entries.Status = Posix_Tools.Commands.Rg.No_Matches
            and then To_String (No_Entries.Output) = "",
            "--max-depth zero visits no directory entries");
         AUnit.Assertions.Assert
           (Test_Support.Occurrences (To_String (Root_Only.Output), "needle") = 2
            and then not Test_Support.Contains (To_String (Root_Only.Output), "nested"),
            "--max-depth one searches files in the root without descending");
      end;

      Test_Support.Delete_If_Exists (Root);
   end Test_Recursive_Traversal;

   procedure Test_File_Listing (T : in out Fixture) is
      pragma Unreferenced (T);
      LF      : constant Character := ASCII.LF;
      Root    : constant String := Test_Support.Work_Path ("rg-files");
      Nested  : constant String := Root & "/nested";
      Visible : constant String := Root & "/visible.adb";
      Missing : constant String := Root & "/missing.adb";
   begin
      Test_Support.Delete_If_Exists (Root);
      Ada.Directories.Create_Path (Nested);
      Test_Support.Write_File (Root & "/.gitignore", "*.gen" & LF);
      Test_Support.Write_File (Visible, "visible" & LF);
      Test_Support.Write_File (Root & "/.hidden.adb", "hidden" & LF);
      Test_Support.Write_File (Root & "/drop.gen", "ignored" & LF);
      Test_Support.Write_File (Nested & "/nested.adb", "nested" & LF);

      declare
         Default_List : constant Run_Outcome := Run_Rg (["--files", Root]);
         Hidden_List  : constant Run_Outcome := Run_Rg (["--files", "--hidden", Root]);
         Ignore_Off   : constant Run_Outcome := Run_Rg (["--files", "--no-ignore", Root]);
         No_Entries   : constant Run_Outcome :=
           Run_Rg (["--files", "--max-depth", "0", Root]);
         Explicit     : constant Run_Outcome := Run_Rg (["--files", Visible]);
         Standard_In  : constant Run_Outcome := Run_Rg (["--files", "-"]);
         Not_Found    : constant Run_Outcome := Run_Rg (["--files", Missing]);
      begin
         AUnit.Assertions.Assert
           (Default_List.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Default_List.Output), Visible & LF)
            and then Test_Support.Contains
              (To_String (Default_List.Output), Nested & "/nested.adb" & LF)
            and then not Test_Support.Contains (To_String (Default_List.Output), ".hidden.adb")
            and then not Test_Support.Contains (To_String (Default_List.Output), "drop.gen"),
            "--files reuses recursive hidden and ignore filtering");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Hidden_List.Output), ".hidden.adb"),
            "--files --hidden includes hidden files");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Ignore_Off.Output), "drop.gen"),
            "--files --no-ignore includes ignored non-hidden files");
         AUnit.Assertions.Assert
           (No_Entries.Status = Posix_Tools.Commands.Rg.No_Matches
            and then To_String (No_Entries.Output) = "",
            "--files honors a zero maximum depth");
         AUnit.Assertions.Assert
           (To_String (Explicit.Output) = Visible & LF
            and then To_String (Standard_In.Output) = "<stdin>" & LF,
            "--files handles explicit files and standard input labels");
         AUnit.Assertions.Assert
           (Not_Found.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains (To_String (Not_Found.Errors), "cannot read"),
            "--files reports a missing explicit path as trouble");
      end;

      Test_Support.Delete_If_Exists (Root);
   end Test_File_Listing;

   procedure Test_Glob_Filtering (T : in out Fixture) is
      pragma Unreferenced (T);
      LF      : constant Character := ASCII.LF;
      Root    : constant String := Test_Support.Work_Path ("rg-globs");
      Source  : constant String := Root & "/src";
      Nested  : constant String := Source & "/nested";
      Build   : constant String := Root & "/build";
      Hidden  : constant String := Root & "/.hidden";
   begin
      Test_Support.Delete_If_Exists (Root);
      Ada.Directories.Create_Path (Nested);
      Ada.Directories.Create_Path (Build);
      Ada.Directories.Create_Path (Hidden);
      Test_Support.Write_File (Root & "/.gitignore", "build/" & LF & "*.gen" & LF);
      Test_Support.Write_File (Root & "/root.adb", "needle root" & LF);
      Test_Support.Write_File (Root & "/root.txt", "needle text" & LF);
      Test_Support.Write_File (Root & "/keep.gen", "needle generated" & LF);
      Test_Support.Write_File (Source & "/main.adb", "needle main" & LF);
      Test_Support.Write_File (Nested & "/child.adb", "needle child" & LF);
      Test_Support.Write_File (Nested & "/child.txt", "needle child text" & LF);
      Test_Support.Write_File (Build & "/output.adb", "needle build" & LF);
      Test_Support.Write_File (Hidden & "/secret.adb", "needle secret" & LF);

      declare
         Ada_Files : constant Run_Outcome := Run_Rg (["--files", "-g", "*.adb", Root]);
         Included_Ignored : constant Run_Outcome := Run_Rg (["--files", "-g", "keep.gen", Root]);
         Ignored_Parent : constant Run_Outcome := Run_Rg (["--files", "-g", "build/**", Root]);
         Included_Parent : constant Run_Outcome :=
           Run_Rg (["--files", "-g", "build", "-g", "build/**", Root]);
         Later_Include : constant Run_Outcome :=
           Run_Rg (["--files", "-g", "!src/**", "-g", "*.adb", Root]);
         Later_Exclude : constant Run_Outcome :=
           Run_Rg (["--files", "-g", "*.adb", "-g", "!src/**", Root]);
         Negative_Only : constant Run_Outcome := Run_Rg (["--files", "-g", "!*.txt", Root]);
         Hidden_Off : constant Run_Outcome := Run_Rg (["--files", "-g", ".hidden/**", Root]);
         Hidden_On : constant Run_Outcome :=
           Run_Rg (["--files", "--hidden", "-g", ".hidden/**", Root]);
         Empty_Glob : constant Run_Outcome := Run_Rg (["--files", "--glob=", Root]);
         Content : constant Run_Outcome := Run_Rg (["needle", "-g", "keep.gen", Root]);
      begin
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Ada_Files.Output), Root & "/root.adb" & LF)
            and then Test_Support.Contains (To_String (Ada_Files.Output), Source & "/main.adb" & LF)
            and then Test_Support.Contains
              (To_String (Ada_Files.Output), Nested & "/child.adb" & LF)
            and then not Test_Support.Contains (To_String (Ada_Files.Output), "root.txt")
            and then not Test_Support.Contains (To_String (Ada_Files.Output), "output.adb"),
            "a slash-free positive glob matches basenames at every traversed depth");
         AUnit.Assertions.Assert
           (To_String (Included_Ignored.Output) = Root & "/keep.gen" & LF,
            "an explicit positive glob re-includes an ignored file");
         AUnit.Assertions.Assert
           (Ignored_Parent.Status = Posix_Tools.Commands.Rg.No_Matches
            and then To_String (Ignored_Parent.Output) = ""
            and then To_String (Included_Parent.Output) = Build & "/output.adb" & LF,
            "an ignored directory must itself be re-included before a descendant glob can select files");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Later_Include.Output), Root & "/root.adb" & LF)
            and then Test_Support.Contains (To_String (Later_Include.Output), Source & "/main.adb" & LF)
            and then not Test_Support.Contains (To_String (Later_Include.Output), "child.adb"),
            "a later include overrides an earlier exclusion without reopening an excluded descendant directory");
         AUnit.Assertions.Assert
           (To_String (Later_Exclude.Output) = Root & "/root.adb" & LF,
            "a later exclusion overrides earlier positive matches and prunes its directory");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Negative_Only.Output), Root & "/root.adb" & LF)
            and then not Test_Support.Contains (To_String (Negative_Only.Output), ".txt"),
            "a negative-only glob policy retains unmatched files");
         AUnit.Assertions.Assert
           (Hidden_Off.Status = Posix_Tools.Commands.Rg.No_Matches
            and then To_String (Hidden_On.Output) = Hidden & "/secret.adb" & LF,
            "glob inclusion does not bypass hidden traversal without --hidden");
         AUnit.Assertions.Assert
           (Empty_Glob.Status = Posix_Tools.Commands.Rg.No_Matches
            and then To_String (Empty_Glob.Output) = "",
            "an empty positive glob deterministically selects no files");
         AUnit.Assertions.Assert
           (To_String (Content.Output) = Root & "/keep.gen:needle generated" & LF,
            "content search and --files share glob override semantics");
      end;

      Test_Support.Delete_If_Exists (Root);
   end Test_Glob_Filtering;

   procedure Test_File_Types (T : in out Fixture) is
      pragma Unreferenced (T);
      LF      : constant Character := ASCII.LF;
      Root    : constant String := Test_Support.Work_Path ("rg-types");
      Ada_File : constant String := Root & "/main.adb";
      Text_File : constant String := Root & "/notes.txt";
      Unknown : constant String := Root & "/mystery.unknownextension";
   begin
      Test_Support.Delete_If_Exists (Root);
      Ada.Directories.Create_Path (Root);
      Test_Support.Write_File (Ada_File, "needle ada" & LF);
      Test_Support.Write_File (Text_File, "needle text" & LF);
      Test_Support.Write_File (Unknown, "needle unknown" & LF);

      declare
         Listed : constant Run_Outcome := Run_Rg (["--type-list"]);
         Ada_Only : constant Run_Outcome := Run_Rg (["--files", "-tada", Root]);
         Not_Ada : constant Run_Outcome := Run_Rg (["--files", "-T", "ada", Root]);
         Union : constant Run_Outcome :=
           Run_Rg (["--files", "-t", "ada", "--type=txt", Root]);
         All_Known : constant Run_Outcome := Run_Rg (["--files", "-t", "all", Root]);
         No_Known : constant Run_Outcome := Run_Rg (["--files", "-Tall", Root]);
      begin
         AUnit.Assertions.Assert
           (Listed.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Listed.Output), "ada: *.adb, *.ads" & LF)
            and then Test_Support.Contains (To_String (Listed.Output), "zstd: *.zst, *.zstd" & LF)
            and then Test_Support.Occurrences (To_String (Listed.Output), LF & "") = 224,
            "--type-list renders the pinned ripgrep 15.2.0 catalog");
         AUnit.Assertions.Assert
           (To_String (Ada_Only.Output) = Ada_File & LF,
            "an attached -t selects one named file type");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Not_Ada.Output), Text_File & LF)
            and then Test_Support.Contains (To_String (Not_Ada.Output), Unknown & LF)
            and then not Test_Support.Contains (To_String (Not_Ada.Output), Ada_File),
            "-T excludes its named type while retaining unknown files");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Union.Output), Ada_File & LF)
            and then Test_Support.Contains (To_String (Union.Output), Text_File & LF)
            and then not Test_Support.Contains (To_String (Union.Output), Unknown),
            "repeated short and long type inclusions form a union");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (All_Known.Output), Ada_File & LF)
            and then Test_Support.Contains (To_String (All_Known.Output), Text_File & LF)
            and then not Test_Support.Contains (To_String (All_Known.Output), Unknown)
            and then To_String (No_Known.Output) = Unknown & LF,
            "the all pseudo-type denotes every known type but not unknown files");
      end;

      declare
         Exclusion_Wins : constant Run_Outcome :=
           Run_Rg (["--files", "-tada", "--type-not=ada", Root]);
         Unknown_Type : constant Run_Outcome := Run_Rg (["--files", "-t", "missing", Root]);
         Explicit : constant Run_Outcome := Run_Rg (["--files", "-tada", Text_File]);
         Content : constant Run_Outcome := Run_Rg (["needle", "-tada", Root]);
         With_Glob : constant Run_Outcome :=
           Run_Rg (["--files", "-tada", "-g", "*.txt", Root]);
      begin
         AUnit.Assertions.Assert
           (Exclusion_Wins.Status = Posix_Tools.Commands.Rg.No_Matches,
            "type exclusions win over inclusions regardless of option order");
         AUnit.Assertions.Assert
           (Unknown_Type.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains
              (To_String (Unknown_Type.Errors), "unrecognized file type: missing"),
            "unknown file types are rejected explicitly");
         AUnit.Assertions.Assert
           (To_String (Explicit.Output) = Text_File & LF,
            "an explicit file operand bypasses directory type filtering");
         AUnit.Assertions.Assert
           (To_String (Content.Output) = Ada_File & ":needle ada" & LF,
            "content search shares the file-type traversal policy");
         AUnit.Assertions.Assert
           (With_Glob.Status = Posix_Tools.Commands.Rg.No_Matches,
            "positive globs and file-type inclusions are intersected");
      end;

      Test_Support.Delete_If_Exists (Root);
   end Test_File_Types;

   procedure Test_Rendering (T : in out Fixture) is
      pragma Unreferenced (T);
      LF     : constant Character := ASCII.LF;
      First  : constant String := Test_Support.Work_Path ("rg-render-first.txt");
      Second : constant String := Test_Support.Work_Path ("rg-render-second.txt");
   begin
      declare
         E_Acute : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
         Numbered : constant Run_Outcome :=
           Run_Rg (["-n", "needle"], "none" & LF & "needle" & LF);
         Column : constant Run_Outcome :=
           Run_Rg (["--column", "needle"], "none" & LF & "xxneedle" & LF);
         Column_Only : constant Run_Outcome :=
           Run_Rg (["--column", "-N", "needle"], "xxneedle" & LF);
         Earliest : constant Run_Outcome :=
           Run_Rg
             (["--column", "-e", "later", "-e", "early"],
              "early then later" & LF);
         UTF8_Column : constant Run_Outcome :=
           Run_Rg (["--column", "needle"], E_Acute & "needle" & LF);
      begin
         AUnit.Assertions.Assert
           (To_String (Numbered.Output) = "2:needle" & LF,
            "-n renders one-based line numbers");
         AUnit.Assertions.Assert
           (To_String (Column.Output) = "2:3:xxneedle" & LF,
            "--column implies line numbers and uses one-based byte offsets");
         AUnit.Assertions.Assert
           (To_String (Column_Only.Output) = "3:xxneedle" & LF,
            "-N suppresses the implied line number without suppressing the column");
         AUnit.Assertions.Assert
           (To_String (Earliest.Output) = "1:1:early then later" & LF,
            "the rendered column is the earliest match across all patterns");
         AUnit.Assertions.Assert
           (To_String (UTF8_Column.Output) = "1:3:" & E_Acute & "needle" & LF,
            "columns retain ripgrep's one-based byte-offset convention for UTF-8 input");
      end;

      Test_Support.Write_File (First, "needle first" & LF);
      Test_Support.Write_File (Second, "needle second" & LF);
      declare
         Forced : constant Run_Outcome := Run_Rg (["-H", "needle", First]);
         Hidden : constant Run_Outcome := Run_Rg (["-I", "-n", "needle", First, Second]);
         Last_Wins : constant Run_Outcome := Run_Rg (["-IH", "needle", First]);
      begin
         AUnit.Assertions.Assert
           (To_String (Forced.Output) = First & ":needle first" & LF,
            "-H forces a filename for one explicit file");
         AUnit.Assertions.Assert
           (To_String (Hidden.Output) = "1:needle first" & LF & "1:needle second" & LF,
            "-I suppresses filenames for multiple files while retaining line numbers");
         AUnit.Assertions.Assert
           (To_String (Last_Wins.Output) = First & ":needle first" & LF,
            "the last filename option wins within a combined short option");
      end;

      declare
         Context : Test_Contexts.Capturing_Context;
         Result  : Posix_Tools.Commands.Results.Result;
      begin
         Context.Initialize ("rg", ["needle"]);
         Test_Contexts.Set_Standard_Input (Context, "needle" & LF);
         Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
         Posix_Tools.Commands.Rg.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = "1:needle" & LF,
            "terminal output enables line numbers by default");
      end;

      Test_Support.Delete_If_Exists (First);
      Test_Support.Delete_If_Exists (Second);
   end Test_Rendering;
   procedure Test_Selection_Controls (T : in out Fixture) is
      pragma Unreferenced (T);
      LF     : constant Character := ASCII.LF;
      First  : constant String := Test_Support.Work_Path ("rg-limit-first.txt");
      Second : constant String := Test_Support.Work_Path ("rg-limit-second.txt");
   begin
      declare
         Inverted : constant Run_Outcome :=
           Run_Rg (["-v", "hit"], "hit" & LF & "first miss" & LF & "second miss" & LF);
         Capped : constant Run_Outcome :=
           Run_Rg (["-vm2", "hit"], "hit" & LF & "first miss" & LF & "second miss" & LF & "third miss" & LF);
         Zero : constant Run_Outcome :=
           Run_Rg (["--max-count=0", "hit"], "hit" & LF);
         Inverted_Column : constant Run_Outcome :=
           Run_Rg (["-v", "--column", "hit"], "hit" & LF & "miss" & LF);
      begin
         AUnit.Assertions.Assert
           (To_String (Inverted.Output) = "first miss" & LF & "second miss" & LF,
            "-v selects lines for which no pattern matches");
         AUnit.Assertions.Assert
           (To_String (Capped.Output) = "first miss" & LF & "second miss" & LF,
            "-m limits selected lines after inversion");
         AUnit.Assertions.Assert
           (Zero.Status = Posix_Tools.Commands.Rg.No_Matches and then To_String (Zero.Output) = "",
            "a maximum count of zero reads no selected lines and returns no-match status");
         AUnit.Assertions.Assert
           (To_String (Inverted_Column.Output) = "2:miss" & LF,
            "inverted output retains implied line numbers but has no match column");
      end;

      Test_Support.Write_File (First, "hit one" & LF & "hit two" & LF);
      Test_Support.Write_File (Second, "hit three" & LF & "hit four" & LF);
      declare
         Per_File : constant Run_Outcome := Run_Rg (["-m1", "hit", First, Second]);
      begin
         AUnit.Assertions.Assert
           (To_String (Per_File.Output) = First & ":hit one" & LF & Second & ":hit three" & LF,
            "the maximum count resets for each searched file");
      end;

      Test_Support.Delete_If_Exists (First);
      Test_Support.Delete_If_Exists (Second);
   end Test_Selection_Controls;

   procedure Test_Result_Modes (T : in out Fixture) is
      pragma Unreferenced (T);
      LF      : constant Character := ASCII.LF;
      First   : constant String := Test_Support.Work_Path ("rg-mode-first.txt");
      Second  : constant String := Test_Support.Work_Path ("rg-mode-second.txt");
      Missing : constant String := Test_Support.Work_Path ("rg-mode-missing.txt");
   begin
      Test_Support.Write_File (First, "hit one" & LF & "none" & LF & "hit two" & LF);
      Test_Support.Write_File (Second, "none" & LF);

      declare
         Count_One : constant Run_Outcome := Run_Rg (["-c", "hit", First]);
         Count_Many : constant Run_Outcome := Run_Rg (["-c", "hit", First, Second]);
         Matching_Files : constant Run_Outcome := Run_Rg (["-l", "hit", First, Second]);
         Without_Match : constant Run_Outcome :=
           Run_Rg (["--files-without-match", "hit", First, Second]);
         Suppressed : constant Run_Outcome :=
           Run_Rg (["--files-without-match", "-m0", "hit", First, Second]);
      begin
         AUnit.Assertions.Assert
           (To_String (Count_One.Output) = "2" & LF,
            "-c reports selected-line counts without a single-file prefix");
         AUnit.Assertions.Assert
           (To_String (Count_Many.Output) = First & ":2" & LF,
            "multi-file counts name only files with selected lines");
         AUnit.Assertions.Assert
           (To_String (Matching_Files.Output) = First & LF,
            "-l emits each file containing a selected line once");
         AUnit.Assertions.Assert
           (Without_Match.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Without_Match.Output) = Second & LF,
            "--files-without-match reports files with no selected lines and succeeds");
         AUnit.Assertions.Assert
           (Suppressed.Status = Posix_Tools.Commands.Rg.No_Matches
            and then To_String (Suppressed.Output) = "",
            "-m0 suppresses files-without-match results as in the reference");
      end;

      declare
         Quiet_Match : constant Run_Outcome := Run_Rg (["-q", "hit"], "hit" & LF);
         Quiet_After_Error : constant Run_Outcome := Run_Rg (["-q", "hit", Missing, First]);
         Quiet_Error : constant Run_Outcome := Run_Rg (["-q", "absent", Missing, First]);
      begin
         AUnit.Assertions.Assert
           (Quiet_Match.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Quiet_Match.Output) = "",
            "-q returns success on the first selected line without output");
         AUnit.Assertions.Assert
           (Quiet_After_Error.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Quiet_After_Error.Output) = ""
            and then Test_Support.Contains (To_String (Quiet_After_Error.Errors), "cannot read"),
            "a quiet match dominates an earlier recoverable input error");
         AUnit.Assertions.Assert
           (Quiet_Error.Status = Posix_Tools.Commands.Rg.Trouble,
            "quiet mode retains trouble status when no match overrides an input error");
      end;

      Test_Support.Delete_If_Exists (First);
      Test_Support.Delete_If_Exists (Second);
   end Test_Result_Modes;

   procedure Test_Match_Result_Modes (T : in out Fixture) is
      pragma Unreferenced (T);
      LF      : constant Character := ASCII.LF;
      E_Acute : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
   begin
      declare
         Matches : constant Run_Outcome :=
           Run_Rg (["-o", "name"], "name name" & LF & "none" & LF);
         Located : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "-o", "name"], "name name" & LF);
         Counted : constant Run_Outcome :=
           Run_Rg (["--count-matches", "name"], "name name" & LF & "none" & LF);
         Count_Via_O : constant Run_Outcome :=
           Run_Rg (["-oc", "name"], "name name" & LF & "none" & LF);
         Lines_Win : constant Run_Outcome :=
           Run_Rg (["--count-matches", "-c", "name"], "name name" & LF & "none" & LF);
      begin
         AUnit.Assertions.Assert
           (To_String (Matches.Output) = "name" & LF & "name" & LF,
            "-o emits each non-overlapping match on its own record");
         AUnit.Assertions.Assert
           (To_String (Located.Output) = "1:1:name" & LF & "1:6:name" & LF,
            "match-only output renders each match's byte column");
         AUnit.Assertions.Assert
           (To_String (Counted.Output) = "2" & LF
            and then To_String (Count_Via_O.Output) = "2" & LF,
            "--count-matches and -o with -c count matches instead of lines");
         AUnit.Assertions.Assert
           (To_String (Lines_Win.Output) = "1" & LF,
            "a later -c counts selected lines again");
      end;

      declare
         First_Wins : constant Run_Outcome :=
           Run_Rg (["-o", "-e", "name", "-e", "nam"], "name" & LF);
         Reversed : constant Run_Outcome :=
           Run_Rg (["-o", "-e", "nam", "-e", "name"], "name" & LF);
         Overlap : constant Run_Outcome :=
           Run_Rg (["-o", "-e", "aba", "-e", "ba"], "aba" & LF);
         Inverted : constant Run_Outcome :=
           Run_Rg (["-o", "-v", "name"], "name" & LF & "whole line" & LF);
      begin
         AUnit.Assertions.Assert
           (To_String (First_Wins.Output) = "name" & LF
            and then To_String (Reversed.Output) = "nam" & LF,
            "pattern order breaks ties between matches at the same byte");
         AUnit.Assertions.Assert
           (To_String (Overlap.Output) = "aba" & LF,
            "the merged pattern set emits globally non-overlapping matches");
         AUnit.Assertions.Assert
           (To_String (Inverted.Output) = "whole line" & LF,
            "-v disables match-only slicing and emits selected whole lines");
      end;

      declare
         Empty_Matches : constant Run_Outcome := Run_Rg (["-o", ""], "ab" & LF);
         Empty_Count : constant Run_Outcome := Run_Rg (["--count-matches", ""], "ab" & LF);
         UTF8_Count : constant Run_Outcome := Run_Rg (["--count-matches", ""], E_Acute & LF);
      begin
         AUnit.Assertions.Assert
           (To_String (Empty_Matches.Output) = LF & LF & LF,
            "zero-length match-only output progresses and terminates");
         AUnit.Assertions.Assert
           (To_String (Empty_Count.Output) = "3" & LF,
            "zero-length matches are counted at all ASCII boundaries");
         AUnit.Assertions.Assert
           (To_String (UTF8_Count.Output) = "2" & LF,
            "zero-length UTF-8 matching progresses by code point while retaining byte offsets");
      end;
   end Test_Match_Result_Modes;

   procedure Test_Pattern_Adapter (T : in out Fixture) is
      pragma Unreferenced (T);
      Pattern    : Patterns.Compiled_Pattern;
      Diagnostic : Patterns.Compile_Diagnostic;
   begin
      Patterns.Compile ("Ada", (others => <>), Pattern, Diagnostic);
      AUnit.Assertions.Assert
        (Diagnostic.Status = Patterns.Pattern_Ok
         and then Patterns.Find_First (Pattern, "ada").Status = Regexp.No_Match,
         "rg matching is case-sensitive by default");

      Patterns.Compile (".", (Fixed_Strings => True, others => <>), Pattern, Diagnostic);
      AUnit.Assertions.Assert
        (Patterns.Find_First (Pattern, "a.b").First = 2
         and then Patterns.Find_First (Pattern, "abc").Status = Regexp.No_Match,
         "fixed strings use Regexp literal compilation");

      Patterns.Compile ("", (others => <>), Pattern, Diagnostic);
      AUnit.Assertions.Assert
        (Diagnostic.Status = Patterns.Pattern_Ok
         and then Patterns.Find_First (Pattern, "text").Status = Regexp.Match_Ok,
         "an empty rg pattern matches without using Regexp's empty source error");

      declare
         E_Acute : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
         Found   : Regexp.Match_Result;
      begin
         Patterns.Compile (".", (others => <>), Pattern, Diagnostic);
         Found := Patterns.Find_First (Pattern, E_Acute);
         AUnit.Assertions.Assert
           (Found.Status = Regexp.Match_Ok and then Found.First = 1 and then Found.Last = 2,
            "UTF-8 mode returns byte offsets for a whole code point");
      end;

      Patterns.Compile ("[", (others => <>), Pattern, Diagnostic);
      AUnit.Assertions.Assert
        (Diagnostic.Status = Patterns.Pattern_Invalid
         and then Diagnostic.Engine_Status = Regexp.Unterminated_Class,
         "compile diagnostics retain the engine status");
   end Test_Pattern_Adapter;
end Rg_Command_Tests;
