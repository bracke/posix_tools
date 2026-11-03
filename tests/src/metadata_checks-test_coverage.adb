with Ada.Strings.Unbounded;
with Registered_Tests;
with Tooling_Checks;

--  The tests the requirements rest on are registered, and the rows that
--  cite them exist. A test is looked up in the suite itself rather than
--  in its registration file's text.
package body Metadata_Checks.Test_Coverage is
   use Ada.Strings.Unbounded;

   function "+" (Text : String) return Unbounded_String renames To_Unbounded_String;

   type Name_List is array (Positive range <>) of Unbounded_String;

   --  Tests registered under exactly these names.
   Required_Tests : constant Name_List :=
      [+"property:option parsing",
       +"command:basename edge cases",
       +"command:dirname edge cases",
       +"property:basename dirname commands",
       +"command:echo data edge cases",
       +"property:echo output",
       +"command:true extension edges",
       +"command:false extension edges",
       +"property:true false operands",
       +"command:cat files",
       +"command:cat continues after missing file",
       +"command:cat standard input",
       +"property:cat byte preservation",
       +"command:cat output failure",
       +"command:head counts",
       +"command:head default limits",
       +"property:head prefix",
       +"property:head standard input",
       +"command:head invalid count",
       +"command:head missing count",
       +"command:head multiple file headers",
       +"command:head standard input",
       +"command:pwd options",
       +"command:pwd context fallbacks",
       +"property:pwd option precedence",
       +"command:tail byte mode edges",
       +"command:tail compact counts",
       +"command:tail follow live",
       +"command:tail invalid count",
       +"command:tail missing count",
       +"command:tail line mode edges",
       +"command:tail multiple file headers",
       +"command:tail plus origin",
       +"command:tail standard input",
       +"property:tail byte suffix",
       +"property:tail standard input bytes",
       +"property:tail line suffix",
       +"streams:byte counting",
       +"streams:utf-8 counting",
       +"command:wc multiple files",
       +"command:wc default and mixed text",
       +"command:wc text counts",
       +"command:wc invalid UTF-8",
       +"command:wc malformed UTF-8",
       +"command:wc code point validity",
       +"command:wc standard input",
       +"property:wc byte count",
       +"property:wc standard input bytes",
       +"property:wc line count",
       +"property:wc standard input lines",
       +"command:end-of-options"];

   --  Groups with at least one registered test each.
   Required_Suites : constant Name_List :=
      [+"regression:REG-CAT-0003",
       +"regression:REG-STDOUT-0004",
       +"regression:REG-TAIL-0004",
       +"regression:REG-WC-0005",
       +"regression:REG-ENV-0001",
       +"regression:REG-VERBOSE-0001",
       +"regression:REG-XARGS-0001",
       +"command:cp",
       +"command:date",
       +"command:dd",
       +"command:env",
       +"command:find",
       +"command:ln",
       +"command:mkdir",
       +"command:mv",
       +"command:printf",
       +"command:rm",
       +"command:rmdir",
       +"command:sort",
       +"command:tee",
       +"command:test",
       +"command:touch",
       +"command:tr",
       +"command:uniq",
       +"command:xargs"];

   procedure Run is
   begin
      for Name of Required_Tests loop
         if not Registered_Tests.Is_Registered (To_String (Name)) then
            Tooling_Checks.Fail ("no registered test named " & To_String (Name));
         end if;
      end loop;

      for Suite of Required_Suites loop
         if not Registered_Tests.Has_Suite (To_String (Suite)) then
            Tooling_Checks.Fail ("no registered test in " & To_String (Suite));
         end if;
      end loop;

      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "PROPERTY-CAT-BYTES-001");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-CAT-0001");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-CAT-0002");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-CAT-0003");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-ENV-0001");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-VERBOSE-0001");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-XARGS-0001");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`--suite cp`");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "Unknown suite names fail with usage status");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "posix_tools_tests test --suite cp");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-HEAD-0001");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-HEAD-0002");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-HEAD-0004");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-STREAMS-0001");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-TAIL-0001");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-TAIL-0002");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-TAIL-0003");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-TAIL-0005");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-TAIL-0006");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-TAIL-0007");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-WC-0001");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-WC-0002");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-WC-0003");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-WC-0006");
      Tooling_Checks.Require_Text (Check, "generated/regressions.csv", "REG-OPTIONS-0001");
   end Run;
end Metadata_Checks.Test_Coverage;
