with Tooling_Checks;

package body Metadata_Checks.Test_Coverage is
   procedure Run is
   begin
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse maximum count");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse overflow");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests-suite.adb", "property:option parsing");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse grouped first option");
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
        (Check, "tests/src/command_tests-suite_entries.adb", "command:echo data edge cases");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:echo output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "echo treats -- backslash and -n as data");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "echo non-sole help preserves empty operand");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:true extension edges");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:false extension edges");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:true false operands");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat files");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat continues after missing file");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat standard input");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:cat byte preservation");
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
        (Check, "docs/testing.md", "`--suite cp`");
      Tooling_Checks.Require_Text
        (Check, "docs/testing.md", "Unknown suite names fail with usage status");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "posix_tools_tests test --suite cp");
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
        (Check, "tests/src/command_tests.adb", "pwd -P -L last option output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd relative PWD fallback output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd dot component fallback output");
      Tooling_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd dot-dot component fallback output");
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
        (Check, "tests/src/command_tests.adb", "wc -l raw output");
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
