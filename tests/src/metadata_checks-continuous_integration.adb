with Project_Tools.Release_Checks;

package body Metadata_Checks.Continuous_Integration is
   procedure Run is
   begin
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "ubuntu-latest");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "macos-15-intel");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "windows-latest");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "pull_request:");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "workflow_dispatch:");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "contents: read");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "timeout-minutes: 60");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "fail-fast: false");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "actions/checkout@v7");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: posix_tools");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/hostkit");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: hostkit");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/messages");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: messages");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/i18n");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: i18n");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/awklib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: awklib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/greplib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: greplib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/sedlib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: sedlib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/regexp");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: regexp");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/httpclient");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: httpclient");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/zlib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: zlib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/tarlib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: tarlib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/cryptolib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: cryptolib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/ssllib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: ssllib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/truststores");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: truststores");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "repository: bracke/terminal_styles");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: terminal_styles");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "repository: bracke/project_tools");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: project_tools");
      Forbid_Text
        (".github/workflows/ci.yml", "actions/checkout@v4", "CI workflow must use Node 24 compatible checkout");
      Forbid_Text
        (".github/workflows/ci.yml", "actions/setup-node@v4", "CI workflow must not pin Node 20 setup actions");
      Forbid_Text
        (".github/workflows/ci.yml", "actions/cache/restore@v4", "CI workflow must not pin Node 20 cache actions");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "alire-project/setup-alire@v6");
      Forbid_Text
        (".github/workflows/ci.yml",
         "alire-project/setup-alire@v6.0.0",
         "CI workflow must use setup-alire v6 branch with Node 24 internals");
      Forbid_Text
        (".github/workflows/ci.yml", "alire-project/setup-alire@v5", "CI workflow must use current setup-alire");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "alr -n build");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "working-directory: posix_tools/tests");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "posix_tools_tests.exe");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "release-check");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "alr -n install gnatprove");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "GITHUB_PATH");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "cygpath -w");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "gnatprove");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "CI-WORKFLOW-GATE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "Node 24 compatible checkout actions");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "sibling dependency checkouts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "Node 24 compatible setup-alire branch");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "PACKAGE-INVENTORY-COMPLETE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "PACKAGE-MANIFEST-COVERAGE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "INTEGRATION-EXECUTABLE-SMOKE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "RELEASE-ARCHIVE-001");
   end Run;
end Metadata_Checks.Continuous_Integration;
