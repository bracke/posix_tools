with Project_Tools.Alire_Manifests.Validation;
with Project_Tools.Files;
with Tooling_Support;

package body Metadata_Checks.Dependencies is
   procedure Run is
      Tests_Manifest : constant String :=
        Project_Tools.Files.Join
          (Tooling_Support.Root, "tests/alire.toml");
   begin
      Require_Crate_Metadata
        ("tests/alire.toml", "posix_tools_tests", "posix_tools_tests.gpr");

      Project_Tools.Alire_Manifests.Validation.Require_Workspace_Pin
        (Tests_Manifest,
         "posix_tools_common",
         "../common",
         Quiet => True);
      Project_Tools.Alire_Manifests.Validation.Require_Workspace_Pin
        (Tests_Manifest,
         "project_tools",
         "../../project_tools",
         Quiet => True);

      --  These are manifest policies, not assertions about how an Ada body is
      --  spelled. Command/source dependency boundaries are checked by parsing
      --  with clauses in Metadata_Checks.Source_Rules.
      Forbid_Text
        ("tests/alire.toml",
         "posix_tools =",
         "tests manifest must not depend on the root binary crate");
      Forbid_Text
        ("tests/alire.toml",
         "hostkit =",
         "tests must reach hostkit through posix_tools_common");
      Forbid_Text
        ("common/alire.toml",
         "aunit =",
         "the production library must not depend on AUnit");
      Forbid_Text
        ("common/alire.toml",
         "project_tools =",
         "the production library must not depend on release tooling");
   end Run;
end Metadata_Checks.Dependencies;
