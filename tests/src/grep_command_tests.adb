with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Greplib.Options;
with Greplib.Patterns;
with Greplib.Results;
with Greplib.Search;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Grep;
with Posix_Tools.Commands.Grep.Patterns;
with Posix_Tools.Commands.Grep.Rendering;
with Posix_Tools.Commands.Results;
with Posix_Tools.Exit_Status;
with Posix_Tools.Version;
with Test_Contexts;
with Test_Support;

package body Grep_Command_Tests is
   use Ada.Strings.Unbounded;
   use type Greplib.Wide_Count;
   use type Posix_Tools.Exit_Status.Code;

   package Rendering renames Posix_Tools.Commands.Grep.Rendering;

   LF : constant Character := ASCII.LF;

   type Run_Outcome is record
      Output : Unbounded_String;
      Errors : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   --  Assert that grep with Args and standard input Input writes Output and
   --  ends with Status.
   procedure Expect
     (Label  : String;
      Args   : Posix_Tools.Arguments.Vector;
      Input  : String;
      Output : String;
      Status : Posix_Tools.Exit_Status.Code);

   --  The lines "1" to "Count", each ended by a newline.
   function Numbers (Count : Positive) return String;

   --  A path under the tests' work directory for grep's files.
   function Path (Name : String) return String;

   --  Run grep with Args, Input as its standard input, and its output
   --  failing after Fail_After bytes when Fail_After is not negative.
   function Run_Grep
     (Args       : Posix_Tools.Arguments.Vector;
      Input      : String := "";
      Fail_After : Integer := -1) return Run_Outcome;

   --  The events of searching Subject for Pattern, an extended regular
   --  expression, in Mode, as Settings renders them for a file named Label.
   function Rendered
     (Subject  : String;
      Pattern  : String;
      Mode     : Greplib.Options.Result_Mode;
      Settings : Rendering.Render_Settings;
      Label    : String;
      Spans    : Greplib.Options.Span_Requirement := Greplib.Options.No_Spans) return String;

   procedure Expect
     (Label  : String;
      Args   : Posix_Tools.Arguments.Vector;
      Input  : String;
      Output : String;
      Status : Posix_Tools.Exit_Status.Code)
   is
      Outcome : constant Run_Outcome := Run_Grep (Args, Input);
   begin
      AUnit.Assertions.Assert
        (To_String (Outcome.Output) = Output,
         Label & ": output [" & To_String (Outcome.Output) & "], errors [" & To_String (Outcome.Errors) & "]");
      AUnit.Assertions.Assert
        (Outcome.Status = Status,
         Label & ": status" & Posix_Tools.Exit_Status.Code'Image (Outcome.Status));
   end Expect;

   function Numbers (Count : Positive) return String is
      Result : Unbounded_String;
   begin
      for I in 1 .. Count loop
         declare
            Image : constant String := Positive'Image (I);
         begin
            Append (Result, Image (Image'First + 1 .. Image'Last) & LF);
         end;
      end loop;
      return To_String (Result);
   end Numbers;

   function Path (Name : String) return String is
   begin
      Ada.Directories.Create_Path (Test_Support.Work_Path ("grep"));
      return Test_Support.Work_Path ("grep/" & Name);
   end Path;

   function Rendered
     (Subject  : String;
      Pattern  : String;
      Mode     : Greplib.Options.Result_Mode;
      Settings : Rendering.Render_Settings;
      Label    : String;
      Spans    : Greplib.Options.Span_Requirement := Greplib.Options.No_Spans) return String
   is
      Context  : aliased Test_Contexts.Capturing_Context;
      Sink     : Rendering.Output_Sink (Context'Access);
      List     : Greplib.Patterns.Pattern_List;
      Options  : Greplib.Options.Search_Options;
      Outcome  : Greplib.Results.Search_Outcome;
      Compiled : Greplib.Patterns.Compilation_Options;
   begin
      Context.Initialize ("grep", Posix_Tools.Arguments.Empty);
      Greplib.Patterns.Append (List, Greplib.Patterns.Regular_Expression_Pattern (Pattern));
      Options.Mode := Mode;
      Options.Spans := Spans;
      Rendering.Configure (Sink, Settings);
      Rendering.Begin_Search (Sink, Label);
      Greplib.Search.Search_String (Subject, Greplib.Patterns.Compile (List, Compiled), Options, Sink, Outcome);
      Rendering.Flush (Sink);
      return Test_Contexts.Output (Context);
   end Rendered;

   function Run_Grep
     (Args       : Posix_Tools.Arguments.Vector;
      Input      : String := "";
      Fail_After : Integer := -1) return Run_Outcome
   is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("grep", Args);
      Test_Contexts.Set_Standard_Input (Context, Input);
      if Fail_After >= 0 then
         Test_Contexts.Set_Output_Failure_After (Context, Fail_After);
      end if;
      Posix_Tools.Commands.Grep.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Grep;

   procedure Test_Basic_To_Extended (T : in out Fixture) is
      pragma Unreferenced (T);

      --  Assert that the basic expression Basic translates to Extended.
      procedure Check (Basic, Extended : String);

      procedure Check (Basic, Extended : String) is
         Translated : constant String := Posix_Tools.Commands.Grep.Patterns.Basic_To_Extended (Basic, "C");
      begin
         AUnit.Assertions.Assert
           (Translated = Extended, "BRE " & Basic & " is ERE " & Extended & ", not " & Translated);
      end Check;
   begin
      Check ("abc", "abc");
      Check ("a\(b\)c", "a(b)c");
      Check ("x\{2,3\}", "x{2,3}");
      Check ("x\{2", "x\{2");
      Check ("a\|b", "a|b");
      Check ("a\+\?", "a+?");
      Check ("a+b?c|d", "a\+b\?c\|d");
      Check ("(x){1}", "\(x\)\{1\}");
      Check ("\.\*", "\.\*");
      Check ("^a.*b$", "^a.*b$");
      Check ("[[:digit:]x]", "[[:digit:]x]");
      Check ("[]a]", "[]a]");
      Check ("[a", "[a");
      Check ("trailing\", "trailing\");
      Check ("[a-c]", "[abc]");
   end Test_Basic_To_Extended;

   procedure Test_Context_Separators (T : in out Fixture) is
      pragma Unreferenced (T);
      Three : constant String := Path ("context-three.txt");
   begin
      Expect
        ("-A only: a group that starts with a selected line is separated",
         ["-A1", "-e", "3", "-e", "4", "-e", "9"], Numbers (20),
         "3" & LF & "4" & LF & "5" & LF & "--" & LF & "9" & LF & "10" & LF & "--" & LF
         & "13" & LF & "14" & LF & "15" & LF & "--" & LF & "19" & LF & "20" & LF,
         Posix_Tools.Exit_Status.Success);
      Expect
        ("-B only",
         ["-B1", "-e", "3", "-e", "9"], Numbers (12),
         "2" & LF & "3" & LF & "--" & LF & "8" & LF & "9" & LF,
         Posix_Tools.Exit_Status.Success);
      Expect
        ("adjacent groups merge",
         ["-n", "-C1", "-e", "5", "-e", "7"], Numbers (9),
         "4-4" & LF & "5:5" & LF & "6-6" & LF & "7:7" & LF & "8-8" & LF,
         Posix_Tools.Exit_Status.Success);

      Test_Support.Write_File (Three, Numbers (3));
      Expect
        ("groups of different files are separated",
         ["-A1", "1", Three, Three], "",
         Three & ":1" & LF & Three & "-2" & LF & "--" & LF & Three & ":1" & LF & Three & "-2" & LF,
         Posix_Tools.Exit_Status.Success);
      Test_Support.Delete_If_Exists (Three);
   end Test_Context_Separators;

   procedure Test_Event_Rendering (T : in out Fixture) is
      pragma Unreferenced (T);
      Subject : constant String := "abba" & LF & "cd" & LF & "cb" & LF;
   begin
      AUnit.Assertions.Assert
        (Rendered
           (Subject, "b", Greplib.Options.Emit_Selected_Records,
            (Prefix_File => True, Line_Number => True, others => False), "f")
         = "f:1:abba" & LF & "f:3:cb" & LF,
         "selected lines with file and line-number prefixes");
      AUnit.Assertions.Assert
        (Rendered
           (Subject, "b+", Greplib.Options.Emit_Selected_Records,
            (Only_Matching => True, Byte_Offset => True, others => False), "f", Greplib.Options.All_Spans)
         = "1:bb" & LF & "9:b" & LF,
         "only the matches, each at its own byte offset");
      AUnit.Assertions.Assert
        (Rendered
           (Subject, "b", Greplib.Options.Count_Selected_Records, (Prefix_File => True, others => False),
            Rendering.Standard_Input_Label)
         = "(standard input):2" & LF,
         "a count named for standard input");
      AUnit.Assertions.Assert
        (Rendered (Subject, "b", Greplib.Options.Source_Names_With_Matches, (others => False), "f") = "f" & LF,
         "the name of a file with a selected line");
      AUnit.Assertions.Assert
        (Rendered
           (Subject, "z", Greplib.Options.Source_Names_Without_Matches,
            (List_Without_Matches => True, others => False), "f")
         = "f" & LF,
         "the name of a file without one");

      declare
         Context : aliased Test_Contexts.Capturing_Context;
         Sink    : Rendering.Output_Sink (Context'Access);
         List    : Greplib.Patterns.Pattern_List;
         Options : Greplib.Options.Search_Options;
         Outcome : Greplib.Results.Search_Outcome;
         Compile : Greplib.Patterns.Compilation_Options;
      begin
         Context.Initialize ("grep", Posix_Tools.Arguments.Empty);
         Test_Contexts.Set_Output_Failure_After (Context, 0);
         Greplib.Patterns.Append (List, Greplib.Patterns.Regular_Expression_Pattern ("."));
         Rendering.Configure (Sink, (Flush_Each_Record => True, others => False));
         Rendering.Begin_Search (Sink, "f");
         Greplib.Search.Search_String
           (Numbers (5), Greplib.Patterns.Compile (List, Compile), Options, Sink, Outcome);
         AUnit.Assertions.Assert (Rendering.Output_Failed (Sink), "a failed write is remembered");
         AUnit.Assertions.Assert
           (Greplib.Results.Selected_Record_Count (Greplib.Results.Summary (Outcome)) = 1,
            "and stops the search at the line that could not be written");
      end;
   end Test_Event_Rendering;

   procedure Test_Help_And_Version (T : in out Fixture) is
      pragma Unreferenced (T);
      Help    : constant Run_Outcome := Run_Grep (["-c", "--help"]);
      Version : constant Run_Outcome := Run_Grep (["--version"]);
      Failed  : constant Run_Outcome := Run_Grep (["--help"], Fail_After => 0);
   begin
      AUnit.Assertions.Assert
        (Test_Support.Contains (To_String (Help.Output), "Usage: grep [OPTION]... PATTERN [FILE]...")
         and then Help.Status = Posix_Tools.Exit_Status.Success,
         "--help after an option writes the help and succeeds");
      AUnit.Assertions.Assert
        (Test_Support.Contains (To_String (Version.Output), "engine greplib")
         and then Version.Status = Posix_Tools.Exit_Status.Success,
         "--version writes the version and succeeds");
      AUnit.Assertions.Assert
        (Failed.Status = Posix_Tools.Commands.Grep.Trouble, "help that cannot be written fails");
      Expect ("identity", ["--posix-tools-identify"], "",
              "schema=1" & LF & "project=posix-tools" & LF & "command=grep" & LF & "version="
              & Posix_Tools.Version.Version_String & LF, Posix_Tools.Exit_Status.Success);
   end Test_Help_And_Version;

   procedure Test_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      --  The capturing context fails each stream after as many bytes: the
      --  output fails, and the diagnostic line, shorter, is still kept.
      Outcome : constant Run_Outcome := Run_Grep (["."], Numbers (100), Fail_After => 100);
   begin
      AUnit.Assertions.Assert
        (Outcome.Status = Posix_Tools.Commands.Grep.Trouble, "a failed write is trouble, status 2");
      AUnit.Assertions.Assert
        (Test_Support.Contains (To_String (Outcome.Errors), "grep: cannot write standard output"),
         "and is reported: [" & To_String (Outcome.Errors) & "]");
   end Test_Output_Failure;

   procedure Test_Output_Is_Not_Truncated (T : in out Fixture) is
      pragma Unreferenced (T);
      Input : constant String := Numbers (20_000);
   begin
      Expect ("every selected line is written", ["."], Input, Input, Posix_Tools.Exit_Status.Success);
   end Test_Output_Is_Not_Truncated;

   procedure Test_Pattern_Lists (T : in out Fixture) is
      pragma Unreferenced (T);
      Empty_File    : constant String := Path ("patterns-empty");
      Blank_Ending  : constant String := Path ("patterns-blank-ending");
      Form_Feed     : constant String := Path ("patterns-form-feed");
      Data          : constant String := Path ("patterns-data");
      Lines         : constant String := "a" & LF & "b" & LF & "c" & LF;
   begin
      Test_Support.Write_File (Empty_File, "");
      Test_Support.Write_File (Blank_Ending, "a" & LF & LF);
      Test_Support.Write_File (Form_Feed, "x" & ASCII.FF & "y" & LF);
      Test_Support.Write_File (Data, Lines);

      Expect ("-e splits its text at newlines", ["-e", "a" & LF & "b"], Lines, "a" & LF & "b" & LF,
              Posix_Tools.Exit_Status.Success);
      Expect ("a pattern operand too", ["c" & LF & "a"], Lines, "a" & LF & "c" & LF,
              Posix_Tools.Exit_Status.Success);
      Expect ("an -e text ending in a newline ends in the empty pattern", ["-c", "-e", "z" & LF], Lines,
              "3" & LF, Posix_Tools.Exit_Status.Success);
      Expect ("a pattern file's empty last line is the empty pattern", ["-c", "-f", Blank_Ending], Lines,
              "3" & LF, Posix_Tools.Exit_Status.Success);
      Expect ("an empty pattern file is a list that matches nothing", ["-f", Empty_File], Lines, "",
              Posix_Tools.Commands.Grep.No_Lines_Selected);
      Expect ("whose inversion selects every line", ["-v", "-f", Empty_File], Lines, Lines,
              Posix_Tools.Exit_Status.Success);
      Expect ("a form feed in a pattern file is an ordinary byte", ["-c", "-f", Form_Feed],
              "x" & ASCII.FF & "y" & LF & "x" & LF & "y" & LF, "1" & LF, Posix_Tools.Exit_Status.Success);
      Expect ("-f - reads the patterns from standard input", ["-f", "-", Data], "b" & LF & "c",
              "b" & LF & "c" & LF, Posix_Tools.Exit_Status.Success);
      Expect ("the empty pattern selects every line", [""], Lines, Lines, Posix_Tools.Exit_Status.Success);
      Expect ("and as a whole line only empty ones", ["-x", "-c", ""], "a" & LF & LF, "1" & LF,
              Posix_Tools.Exit_Status.Success);

      declare
         Missing : constant Run_Outcome := Run_Grep (["-f", Path ("patterns-missing"), "a"]);
      begin
         AUnit.Assertions.Assert
           (Missing.Status = Posix_Tools.Commands.Grep.Trouble
            and then Test_Support.Contains (To_String (Missing.Errors), "cannot read pattern file"),
            "a pattern file that cannot be read is trouble");
      end;

      Test_Support.Delete_If_Exists (Empty_File);
      Test_Support.Delete_If_Exists (Blank_Ending);
      Test_Support.Delete_If_Exists (Form_Feed);
      Test_Support.Delete_If_Exists (Data);
   end Test_Pattern_Lists;

   procedure Test_Quiet_Selection_Wins_Over_Errors (T : in out Fixture) is
      pragma Unreferenced (T);
      Missing : constant String := Path ("quiet-missing");
   begin
      Expect ("-q with a selected line after an error succeeds", ["-q", "3", Missing, "-"], Numbers (5), "",
              Posix_Tools.Exit_Status.Success);
      Expect ("-q without one is trouble", ["-q", "9", Missing, "-"], Numbers (5), "",
              Posix_Tools.Commands.Grep.Trouble);
      Expect ("without -q the error decides", ["3", Missing, "-"], Numbers (5), "(standard input):3" & LF,
              Posix_Tools.Commands.Grep.Trouble);
   end Test_Quiet_Selection_Wins_Over_Errors;

   procedure Test_Standard_Input_Label (T : in out Fixture) is
      pragma Unreferenced (T);
      Lines : constant String := "x" & LF & "y" & LF;
   begin
      Expect ("-H", ["-H", "x"], Lines, "(standard input):x" & LF, Posix_Tools.Exit_Status.Success);
      Expect ("-l", ["-l", "x"], Lines, "(standard input)" & LF, Posix_Tools.Exit_Status.Success);
      Expect ("-L", ["-L", "z"], Lines, "(standard input)" & LF, Posix_Tools.Commands.Grep.No_Lines_Selected);
      Expect ("-c -H", ["-c", "-H", "x"], Lines, "(standard input):1" & LF, Posix_Tools.Exit_Status.Success);
      Expect ("an explicit -", ["-H", "y", "-"], Lines, "(standard input):y" & LF,
              Posix_Tools.Exit_Status.Success);
   end Test_Standard_Input_Label;
end Grep_Command_Tests;
