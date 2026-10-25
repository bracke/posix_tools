with Ada.Strings.Fixed;
with Posix_Tools.Version;
with Project_Tools.Files;
with Project_Tools.Release_Checks;
with Tooling_Support;

package body Metadata_Checks.Tooling_Docs is
   use Tooling_Support;

   procedure Run (Writes_Release_Checksums : Boolean) is
      procedure Require_Text_Before
        (Path          : String;
         Earlier_Text  : String;
         Later_Text    : String;
         Failure_Label : String)
      is
         Content : constant String :=
           Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));
         Earlier : constant Natural := Ada.Strings.Fixed.Index (Content, Earlier_Text);
         Later   : constant Natural := Ada.Strings.Fixed.Index (Content, Later_Text);
      begin
         if Earlier = 0 then
            Project_Tools.Release_Checks.Fail (Failure_Label & ": missing earlier marker");
         elsif Later = 0 then
            Project_Tools.Release_Checks.Fail (Failure_Label & ": missing later marker");
         elsif Earlier >= Later then
            Project_Tools.Release_Checks.Fail (Failure_Label & ": markers are out of order");
         end if;
      end Require_Text_Before;
   begin
      Project_Tools.Release_Checks.Require_File (Check, "docs/ai.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/architecture.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/conformance.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/development.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/portability.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/proof-coverage.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/release-process.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/security.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/testing.md");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/release-process.md", "Node 24-compatible checkout action");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/development.md", "Node 24-compatible checkout action");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/portability.md", "Node 24-compatible checkout action");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Repository Map");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Package Map");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Dependency Rules");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Allowed Imports");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Prohibited Imports");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Project Invariants");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Command Workflow");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Test Requirements");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Localization Rules");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Styling Rules");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/ai.md", "Help, root headings, and human diagnostics may be styled");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/ai.md", "stderr terminal status for diagnostics");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Resource Policies");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Completion Criteria");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Rejected Architectures");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/ai.md", "Direct Hostkit use from command algorithms");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/ai.md", "Shell, Python, JavaScript, Make, CMake, or PowerShell project tooling");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`posix_tools_tests`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`test --suite <name>`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`test --category unit`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "`test --category integration`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "`test --category conformance`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "`test --category regression`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`build`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`check`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`format-check`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`docs`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`prove`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`package`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`release-check`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`release`");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "docs/testing.md",
         "`posix_tools_tests format-check` scans maintained Ada, Alire/GPR, Markdown, CSV,");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/format_checks.adb", "function Has_Tab");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/format_checks.adb", "function Has_Trailing_Whitespace");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/format_checks.adb", "function Has_Multiple_Blank_Lines");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/format_checks.adb", "function Is_Checked_Text_File");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""test""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""check""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""release-check""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "elsif Command = ""release-check"" then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Run_Test_Selector_Smoke;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Run_Staged_Verification;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Run_Executable_Integration_Smoke;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "root executable help");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Executable & "" executable help""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "cp executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "date executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "dd executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "env executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "find executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "ln executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "mkdir executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "mv executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "printf executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "rm executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "rmdir executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "sort executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "tee executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test executable status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "touch executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "tr executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "uniq executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "xargs executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Generate_Release_Archive;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Generate_Release_Checksums;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Run_Proof_Checks;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""release""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "elsif Command = ""release"" then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Require_Clean_Source_Tree;");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "tests/src/posix_tools_tests.adb",
         "Require_Clean_Source_Tree;" & Character'Val (10) & "      Generate_Docs;");
      Require_Text_Before
        ("tests/src/posix_tools_tests.adb",
         "elsif Command = ""release"" then",
         "Ada.Text_IO.Put_Line (""release: completed by Ada project_tools driver"");",
         "release branch must run clean-tree-gated release work before completion");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "release: completed by Ada project_tools driver");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""build""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""conformance""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""format-check""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""docs""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""prove""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""package""");
      Require_Synchronized_Version ("alire.toml");
      Require_Synchronized_Version ("common/alire.toml");
      Require_Synchronized_Version ("tests/alire.toml");
      Require_Synchronized_Version ("common/src/posix_tools-version.ads");
      Require_Synchronized_Version ("CHANGELOG.md");
      Require_Synchronized_Version ("generated/manual-index.md");
      Require_Synchronized_Version ("generated/package-manifest.txt");
      Require_Synchronized_Version ("generated/release-checksums.txt");
      Require_Exact_Line
        ("alire.toml",
         "version = """ & Posix_Tools.Version.Version_String & """",
         "root manifest version");
      Require_Exact_Line
        ("common/alire.toml",
         "version = """ & Posix_Tools.Version.Version_String & """",
         "common manifest version");
      Require_Exact_Line
        ("tests/alire.toml",
         "version = """ & Posix_Tools.Version.Version_String & """",
         "tests manifest version");
      Require_Exact_Line
        ("common/src/posix_tools-version.ads",
         "   Version_String : constant String := """ & Posix_Tools.Version.Version_String & """;",
         "compiled version constant");
      Require_Exact_Line ("CHANGELOG.md", "## " & Posix_Tools.Version.Version_String, "changelog version");
      Require_Exact_Line
        ("generated/manual-index.md",
         "Version: " & Posix_Tools.Version.Version_String,
         "manual index version");
      Require_Exact_Line
        ("generated/package-manifest.txt",
         "posix-tools package manifest " & Posix_Tools.Version.Version_String,
         "package manifest version header");
      if Writes_Release_Checksums then
         Require_Exact_Line
           ("generated/release-checksums.txt",
            "posix-tools release checksums " & Posix_Tools.Version.Version_String,
            "release checksum version header");
      end if;
   end Run;
end Metadata_Checks.Tooling_Docs;
