with Tooling_Checks;

package body Metadata_Checks.Test_Coverage is
   procedure Run is
   begin
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.ads", "type Count is range 0 .. 2 ** 63 - 1;");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.ads", "Valid, Empty, Invalid_Syntax");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.ads", "Negative_Not_Permitted, Overflow");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Empty, Value => 0)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Negative_Not_Permitted, Value => 0)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Invalid_Syntax, Value => 0)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Overflow, Value => 0)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "if Value > (Count'Last - Digit_Value (Ch)) / 10");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse maximum count");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse overflow");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-arguments-parsing.ads", "Unknown_Option");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-arguments-parsing.ads", "Missing_Argument");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Current = ""--""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Current = ""-""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Position.Offset < Current'Length");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Position.Index < Argument_Count");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-arguments-parsing.adb", "Posix_Tools.Option_Parsing.Decide_Short");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests-suite.adb", "property:option parsing");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse grouped first option");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "option parser property seed 0x4F505453");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse attached option argument");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse separate option argument");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse end-of-options");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse lone hyphen operand");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse unknown option");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse missing option argument");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "function Basename");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "function Dirname");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "Collapse_Leading_Root");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "Trim_Trailing_Slashes");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-basename.adb", "Operand_Count > 2");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dirname.adb", "Operand_Count > 1");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:basename edge cases");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:dirname edge cases");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:basename dirname commands");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename command empty");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename non-ASCII suffix");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename command backslash");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "dirname nested two leading slash");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "dirname command backslash");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename dirname command property seed 0xBA5ED123");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Context.Put (Context.Argument (I))");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Context.Put ("" "")");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Conventional => False");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:echo data edge cases");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:echo output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "echo treats -- backslash and -n as data");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "echo non-sole help preserves empty operand");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "echo property seed 0xEC400001");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-true_command.adb", "Posix_Tools.Exit_Status.Success");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-false_command.adb", "Posix_Tools.Exit_Status.Operational_Failure");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-true_command.adb", "Conventional => False");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-false_command.adb", "Conventional => False");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:true extension edges");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:false extension edges");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:true false operands");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "true false operand property seed 0x7F00F15E");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-basename.adb", "Context.Argument (1) = ""--""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dirname.adb", "Context.Argument (1) = ""--""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "Context.Argument (1) = ""--""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "File_Helpers.Copy_File");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "All_Ok := All_Ok and Ok");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "Copy_File (Context, ""-"", Ok)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "if File_Name = ""-"" then");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Copy_Standard_Input (Context, Ok)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Context.Put (To_String (Buffer, Last))");
      Tooling_Checks.Require_Text
        (Check,
         "common/src/posix_tools-commands-file_helpers.adb",
         "Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat files");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat continues after missing file");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat standard input");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:cat byte preservation");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "seed 0x50540003");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "PROPERTY-CAT-BYTES-001");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat output failure");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "cat continues after missing file");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "cat output failure has no read diagnostic");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-CAT-0001");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-CAT-0002");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-CAT-0003");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-CAT-0003");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-STDOUT-0004");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-TAIL-0004");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-WC-0005");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-ENV-0001");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-VERBOSE-0001");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-XARGS-0001");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-ENV-0001");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-VERBOSE-0001");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-XARGS-0001");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cp");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:date");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:dd");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:env");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:find");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:ln");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:mkdir");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:mv");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:printf");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:rm");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:rmdir");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:sort");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tee");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:test");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:touch");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tr");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:uniq");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:xargs");
      Tooling_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector suite cp");
      Tooling_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector suite xargs");
      Tooling_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector suite root");
      Tooling_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector unknown suite");
      Tooling_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "posix_tools_tests test --suite cp");
      Tooling_Checks.Require_Text
        (Check, "docs/testing.md", "`--suite cp`");
      Tooling_Checks.Require_Text
        (Check, "docs/testing.md", "Unknown suite names fail with usage status");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "posix_tools_tests test --suite cp");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Argument (Index) = ""--""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Requested  : Posix_Tools.Numbers.Count := 10");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Argument (Index) = ""-n""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Argument (Index) (1 .. 2) = ""-n""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Parse_Nonnegative");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Missing_Option_Argument, ""-n""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Invalid_Line_Count");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Sources := (if First_File > Count then 1");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Put_Line (""==> "" & Context.Argument (I)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Copy_Line_Prefix");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Finish_Line_Prefix");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head counts");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head default limits");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:head prefix");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:head standard input");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head invalid count");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head multiple file headers");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head standard input");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head long default output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head prefix property seed 0x48454144");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head stdin property seed 0x4845AD15");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head zero output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head repeated -n uses last count");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head leading plus count status");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head missing count status");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head preserves final partial line");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head multiple file headers");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head repeated stdin is not rewound");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-HEAD-0001");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-HEAD-0002");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-HEAD-0004");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-STREAMS-0001");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Stop_Options : Boolean := False;");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Argument (I) = ""--""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Argument (I) = ""-L""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Argument (I) = ""-P""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Logical := True");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Logical := False");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Usable_Logical_Path");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Environment_Value (""PWD"")");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Path_Names_Current_Directory");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Try_Physical_Current_Directory");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:pwd options");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:pwd context fallbacks");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:pwd option precedence");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd -L output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd -P output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd last option wins");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd option precedence property seed 0x50574431");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd -P -L last option output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd relative PWD fallback output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd dot component fallback output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd dot-dot component fallback output");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""--""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-tail_counts.ads", "type Count_Origin is (From_End, From_Start)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Current_Mode : Mode := Line_Mode");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Requested  : Posix_Tools.Numbers.Count := 10");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-n""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-c""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-f""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-F""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""--follow""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) (2) = 'n'");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) (2) = 'c'");
      Tooling_Checks.Require_Text
        (Check,
         "common/src/posix_tools-tail_counts.adb",
         "Text (Text'First) = '+'");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Posix_Tools.Tail_Counts.Parse_Count");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Missing_Option_Argument");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Invalid_Count");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "procedure Copy");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Copy_Line_Suffix");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Copy_Lines_From");
      Tooling_Checks.Require_Text
        (Check,
         "common/src/posix_tools-commands-tail.adb",
         "Context.Put_Line (""==> "" & Context.Argument (File_Index)");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail byte mode edges");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail compact counts");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail follow live");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail invalid count");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail line mode edges");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail multiple file headers");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail plus origin");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail standard input");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:tail byte suffix");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:tail standard input bytes");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:tail line suffix");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail default ten lines from end output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -c property seed 0x5441494C");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail stdin -c property seed 0x54414953");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -n property seed 0x5441494E");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -c2 compact output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -c+4 compact output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -f live status");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail --follow live status");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -F reopen status");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail later -c overrides earlier -n");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail later -n overrides earlier -c");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -n +2 output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail lone plus count status");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail missing -c count status");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail final partial line output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail multiple file headers");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail repeated stdin is not rewound");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0001");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0002");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0003");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0005");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0006");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Context.Argument (First_File) = ""--""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Show_L := True");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Show_W := True");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Show_C := True");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "when 'm' => Show_M := True");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Posix_Tools.Wc_Fields.Needs_Text_Decoding");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Total.Lines := Total.Lines + C.Lines");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Print_Counts (Context, Total, ""total""");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Text_Invalid (State)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Increment (Self.Current.Bytes)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Increment (Self.Current.Lines)");
      Tooling_Checks.Require_Text
        (Check,
         "common/src/posix_tools-streams-counting.adb",
         "Increment (Self.Current.Characters)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Increment (Self.Current.Words)");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Posix_Tools.Text.UTF_8.Decode");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Byte in 16#C2# .. 16#DF#");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Self.Accumulator in 16#D800# .. 16#DFFF#");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests-suite.adb", "streams:byte counting");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests-suite.adb", "streams:utf-8 counting");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc multiple files");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc default and mixed text");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc text counts");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc invalid UTF-8");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc malformed UTF-8");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc standard input");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc byte count");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc standard input bytes");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc line count");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc standard input lines");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc default field order");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -c raw output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -c property seed 0x5EEDC0DE");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc stdin -c property seed 0x57C00001");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -l raw output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -l property seed 0x1F1E5EED");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc stdin -l property seed 0x57C0000A");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc multiple file totals");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc repeated stdin is not rewound");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -m output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc mixed invalid suppresses output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc overlong suppresses output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc surrogate suppresses output");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0001");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0002");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0003");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0006");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:end-of-options");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head skips -- after count");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail skips -- after count");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc skips -- after option");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-OPTIONS-0001");
   end Run;
end Metadata_Checks.Test_Coverage;
