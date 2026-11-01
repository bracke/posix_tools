with Tooling_Checks;

package body Metadata_Checks.Requirements is
   procedure Run is
   begin
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "COMMAND-IMPORT-BOUNDARY-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "POSIX-WC-UTF8-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "TEXT-UTF8-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "TEXT-WHITESPACE-001");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Expected_Continuations");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Minimum_Code_Point");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Self.Accumulator < Self.Minimum_Code_Point");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Self.Accumulator in 16#D800# .. 16#DFFF#");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Self.Accumulator > 16#10FFFF#");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Status := Invalid");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "incomplete UTF-8");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "surrogate UTF-8 rejected");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "out-of-range UTF-8 rejected");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "decoder rejects overlong starter");
      Tooling_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0004");
      Tooling_Checks.Require_Text
        (Check, "common/generated/posix_tools-text-whitespace_data.ads", "Unicode_Version");
      Tooling_Checks.Require_Text
        (Check, "common/generated/posix_tools-text-whitespace_data.ads", "Unicode License v3");
      Tooling_Checks.Require_Text
        (Check, "common/generated/posix_tools-text-whitespace_data.ads", "PropList.txt White_Space property");
      Tooling_Checks.Require_Text
        (Check, "common/generated/posix_tools-text-whitespace_data.ads", "White_Space_Ranges");
      Tooling_Checks.Require_Text
        (Check, "common/src/posix_tools-text-classification.adb", "Whitespace_Data.Is_Whitespace");
      Tooling_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "classification includes range midpoint");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "PRESENTATION-STYLES-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "help root headings and diagnostics");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "HOST-ADAPTER-TERMINAL-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "standard-error terminal status");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "HOST-ADAPTER-FILE-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "NONPOSIX-WC-LINE-LENGTH-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "VERSION-GENERATION-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "VERSION-LOCALE-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "IDENTITY-LOCALE-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "POSIX-TAIL-COMPACT-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "STATE-HEAD-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "STATE-TAIL-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-STDIN-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-STDOUT-FAIL-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-STDOUT-FAIL-002");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-CHUNK-ITERATION-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "ROOT-LIST-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "PROPERTY-ROOT-LIST-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "ROOT-LIST-LOCALE-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "ROOT-VERIFY-LOCALE-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "PROPERTY-ROOT-HELP-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "PROPERTY-ROOT-PATHS-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "PROPERTY-ROOT-VERIFY-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "ROOT-VERIFY-BOUNDED-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "ROOT-VERIFY-SHADOWED-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "PLATFORM-CI-001");
      Tooling_Checks.Require_Text (Check, "docs/conformance.md", "Linux, Windows, and macOS");
      Tooling_Checks.Require_Text (Check, "docs/portability.md", "option prefix is `-`");
      Tooling_Checks.Require_Text
        (Check, "docs/portability.md", "end-of-options marker is `--`");
      Tooling_Checks.Require_Text
        (Check, "docs/portability.md", "lexical pathname separator is `/`");
      Tooling_Checks.Require_Text
        (Check, "docs/portability.md", "POSIX line delimiter is LF");
      Tooling_Checks.Require_Text
        (Check, "docs/portability.md", "executable suffix is `.exe`");
      Tooling_Checks.Require_Text
        (Check, "docs/portability.md", "byte-processing mode is binary");
      Tooling_Checks.Require_Text
        (Check, "docs/portability.md", "backslash is an ordinary character");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "DOCS-AI-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "stderr diagnostic styling policy");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "DOCS-MANPAGES-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "DOCS-MANPAGES-CURRENT-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "DOCS-COMMAND-INDEX-CURRENT-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "DOCS-CHANGELOG-CURRENT-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "DOCS-COMMAND-SECTIONS-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "GPR-DIRS-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "RELEASE-CLEAN-TREE-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "TOOLING-ADA-ONLY-001");
      Tooling_Checks.Require_Text (Check, "generated/requirements.csv", "EXCEPTION-NO-SILENT-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "TOOLING-SELECTOR-SMOKE-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "MANIFEST-GRAPH-004");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "MANIFEST-GRAPH-005");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "MANIFEST-CRATE-METADATA-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "LOCAL-PINS-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "PORTABILITY-WINDOWS-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "TOOLING-COMMAND-SURFACE-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "FORMAL-PROOF-CI-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "STAGED-VERIFY-ROOT-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "INTEGRATED-COMMAND-SCOPE-001");
      Tooling_Checks.Require_Text
        (Check, "generated/command_inventory.csv", "awk,posix_tools_awk");
      Tooling_Checks.Require_Text
        (Check, "generated/command_inventory.csv", "grep,posix_tools_grep");
      Tooling_Checks.Require_Text
        (Check, "generated/command_inventory.csv", "sed,posix_tools_sed");
   end Run;
end Metadata_Checks.Requirements;
