with Project_Tools.Release_Checks;

package body Metadata_Checks.Test_Coverage is
   procedure Run is
   begin
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.ads", "type Count is range 0 .. 2 ** 63 - 1;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.ads", "Valid, Empty, Invalid_Syntax");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.ads", "Negative_Not_Permitted, Overflow");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Empty, Value => 0)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Negative_Not_Permitted, Value => 0)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Invalid_Syntax, Value => 0)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Overflow, Value => 0)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "if Value > (Count'Last - Digit_Value (Ch)) / 10");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse maximum count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse overflow");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-arguments-parsing.ads", "Unknown_Option");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-arguments-parsing.ads", "Missing_Argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Current = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Current = ""-""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Position.Offset < Current'Length");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Position.Index < Argument_Count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-arguments-parsing.adb", "Posix_Tools.Option_Parsing.Decide_Short");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests-suite.adb", "property:option parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse grouped first option");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "option parser property seed 0x4F505453");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse attached option argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse separate option argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse end-of-options");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse lone hyphen operand");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse unknown option");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse missing option argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "function Basename");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "function Dirname");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "Collapse_Leading_Root");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "Trim_Trailing_Slashes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-basename.adb", "Operand_Count > 2");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dirname.adb", "Operand_Count > 1");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:basename edge cases");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:dirname edge cases");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:basename dirname commands");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename command empty");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename non-ASCII suffix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename command backslash");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "dirname nested two leading slash");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "dirname command backslash");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename dirname command property seed 0xBA5ED123");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Context.Put (Context.Argument (I))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Context.Put ("" "")");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Conventional => False");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:echo data edge cases");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:echo output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "echo treats -- backslash and -n as data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "echo non-sole help preserves empty operand");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "echo property seed 0xEC400001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-true_command.adb", "Posix_Tools.Exit_Status.Success");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-false_command.adb", "Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-true_command.adb", "Conventional => False");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-false_command.adb", "Conventional => False");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:true extension edges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:false extension edges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:true false operands");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "true false operand property seed 0x7F00F15E");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-basename.adb", "Context.Argument (1) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dirname.adb", "Context.Argument (1) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "Context.Argument (1) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "File_Helpers.Copy_File");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "All_Ok := All_Ok and Ok");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "Copy_File (Context, ""-"", Ok)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "if File_Name = ""-"" then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Copy_Standard_Input (Context, Ok)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Context.Put (To_String (Buffer, Last))");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-commands-file_helpers.adb",
         "Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat files");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat continues after missing file");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:cat byte preservation");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "seed 0x50540003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "PROPERTY-CAT-BYTES-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat output failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "cat continues after missing file");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "cat output failure has no read diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-CAT-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-CAT-0002");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-CAT-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-CAT-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-STDOUT-0004");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-TAIL-0004");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-WC-0005");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-ENV-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-VERBOSE-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-XARGS-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-ENV-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-VERBOSE-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-XARGS-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cp");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:date");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:dd");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:env");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:find");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:ln");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:mkdir");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:mv");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:printf");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:rm");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:rmdir");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:sort");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tee");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:test");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:touch");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tr");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:uniq");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:xargs");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector suite cp");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector suite xargs");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector suite root");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector unknown suite");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "posix_tools_tests test --suite cp");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "`--suite cp`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "Unknown suite names fail with usage status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "posix_tools_tests test --suite cp");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Argument (Index) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Requested  : Posix_Tools.Numbers.Count := 10");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Argument (Index) = ""-n""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Argument (Index) (1 .. 2) = ""-n""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Parse_Nonnegative");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Missing_Option_Argument, ""-n""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Invalid_Line_Count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Sources := (if First_File > Count then 1");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Put_Line (""==> "" & Context.Argument (I)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Copy_Line_Prefix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Finish_Line_Prefix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head counts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head default limits");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:head prefix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:head standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head invalid count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head multiple file headers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head long default output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head prefix property seed 0x48454144");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head stdin property seed 0x4845AD15");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head zero output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head repeated -n uses last count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head leading plus count status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head missing count status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head preserves final partial line");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head multiple file headers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head repeated stdin is not rewound");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-HEAD-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-HEAD-0002");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-HEAD-0004");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-STREAMS-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Stop_Options : Boolean := False;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Argument (I) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Argument (I) = ""-L""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Argument (I) = ""-P""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Logical := True");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Logical := False");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Usable_Logical_Path");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Environment_Value (""PWD"")");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Path_Names_Current_Directory");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Try_Physical_Current_Directory");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:pwd options");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:pwd context fallbacks");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:pwd option precedence");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd -L output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd -P output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd last option wins");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd option precedence property seed 0x50574431");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd -P -L last option output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd relative PWD fallback output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd dot component fallback output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd dot-dot component fallback output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-tail_counts.ads", "type Count_Origin is (From_End, From_Start)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Current_Mode : Mode := Line_Mode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Requested  : Posix_Tools.Numbers.Count := 10");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-n""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-c""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-f""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-F""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""--follow""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) (2) = 'n'");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) (2) = 'c'");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-tail_counts.adb",
         "Text (Text'First) = '+'");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Posix_Tools.Tail_Counts.Parse_Count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Missing_Option_Argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Invalid_Count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "procedure Copy");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Copy_Line_Suffix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Copy_Lines_From");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-commands-tail.adb",
         "Context.Put_Line (""==> "" & Context.Argument (File_Index)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail byte mode edges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail compact counts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail follow live");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail invalid count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail line mode edges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail multiple file headers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail plus origin");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:tail byte suffix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:tail standard input bytes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:tail line suffix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail default ten lines from end output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -c property seed 0x5441494C");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail stdin -c property seed 0x54414953");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -n property seed 0x5441494E");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -c2 compact output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -c+4 compact output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -f live status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail --follow live status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -F reopen status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail later -c overrides earlier -n");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail later -n overrides earlier -c");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -n +2 output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail lone plus count status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail missing -c count status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail final partial line output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail multiple file headers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail repeated stdin is not rewound");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0002");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0005");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0006");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Context.Argument (First_File) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Show_L := True");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Show_W := True");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Show_C := True");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "when 'm' => Show_M := True");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Posix_Tools.Wc_Fields.Needs_Text_Decoding");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Total.Lines := Total.Lines + C.Lines");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Print_Counts (Context, Total, ""total""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Text_Invalid (State)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Increment (Self.Current.Bytes)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Increment (Self.Current.Lines)");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-streams-counting.adb",
         "Increment (Self.Current.Characters)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Increment (Self.Current.Words)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Posix_Tools.Text.UTF_8.Decode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Byte in 16#C2# .. 16#DF#");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Self.Accumulator in 16#D800# .. 16#DFFF#");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests-suite.adb", "streams:byte counting");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests-suite.adb", "streams:utf-8 counting");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc multiple files");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc default and mixed text");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc text counts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc invalid UTF-8");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc malformed UTF-8");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc byte count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc standard input bytes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc line count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc standard input lines");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc default field order");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -c raw output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -c property seed 0x5EEDC0DE");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc stdin -c property seed 0x57C00001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -l raw output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -l property seed 0x1F1E5EED");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc stdin -l property seed 0x57C0000A");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc multiple file totals");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc repeated stdin is not rewound");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -m output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc mixed invalid suppresses output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc overlong suppresses output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc surrogate suppresses output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0002");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0006");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:end-of-options");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head skips -- after count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail skips -- after count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc skips -- after option");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-OPTIONS-0001");
   end Run;
end Metadata_Checks.Test_Coverage;
