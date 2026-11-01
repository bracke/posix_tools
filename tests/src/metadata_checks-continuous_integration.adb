with Tooling_Checks;

package body Metadata_Checks.Continuous_Integration is
   procedure Run is
   begin
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "ubuntu-latest");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "macos-15-intel");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "windows-latest");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "pull_request:");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "workflow_dispatch:");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "contents: read");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "timeout-minutes: 60");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "fail-fast: false");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "actions/checkout@v7");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: posix_tools");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/hostkit");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: hostkit");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/messages");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: messages");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/i18n");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: i18n");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/awklib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: awklib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/greplib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: greplib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/sedlib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: sedlib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/regexp");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: regexp");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/httpclient");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: httpclient");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/zlib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: zlib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/tarlib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: tarlib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/cryptolib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: cryptolib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/ssllib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: ssllib");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/truststores");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: truststores");
      Tooling_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "repository: bracke/terminal_styles");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: terminal_styles");
      Tooling_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "repository: bracke/project_tools");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: project_tools");
      Forbid_Text
        (".github/workflows/ci.yml", "actions/checkout@v4", "CI workflow must use Node 24 compatible checkout");
      Forbid_Text
        (".github/workflows/ci.yml", "actions/setup-node@v4", "CI workflow must not pin Node 20 setup actions");
      Forbid_Text
        (".github/workflows/ci.yml", "actions/cache/restore@v4", "CI workflow must not pin Node 20 cache actions");
      Tooling_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "alire-project/setup-alire@v6");
      Forbid_Text
        (".github/workflows/ci.yml",
         "alire-project/setup-alire@v6.0.0",
         "CI workflow must use setup-alire v6 branch with Node 24 internals");
      Forbid_Text
        (".github/workflows/ci.yml", "alire-project/setup-alire@v5", "CI workflow must use current setup-alire");
      Tooling_Checks.Require_Text (Check, ".github/workflows/ci.yml", "alr -n build");
      Tooling_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "working-directory: posix_tools/tests");
      Tooling_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "posix_tools_tests.exe");
      Tooling_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "release-check");
      Tooling_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "alr -n install gnatprove");
      Tooling_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "GITHUB_PATH");
      Tooling_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "cygpath -w");
      Tooling_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "gnatprove");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "CI-WORKFLOW-GATE-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "Node 24 compatible checkout actions");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "sibling dependency checkouts");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "Node 24 compatible setup-alire branch");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "PACKAGE-INVENTORY-COMPLETE-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "PACKAGE-MANIFEST-COVERAGE-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "INTEGRATION-EXECUTABLE-SMOKE-001");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "RELEASE-ARCHIVE-001");
   end Run;
end Metadata_Checks.Continuous_Integration;
