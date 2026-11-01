with Posix_Tools.Version;
with Tooling_Checks;
with Tooling_Steps;

package body Metadata_Checks.Tooling_Docs is
   procedure Run (Writes_Release_Checksums : Boolean) is
      --  What the subcommands run, checked on the step lists the driver
      --  runs rather than on the driver's source text.
      procedure Require_Subcommand_Steps is
         use Tooling_Steps;

         function Image (Item : Step) return String is (Step'Image (Item));

         procedure Require_Step (Item : Subcommand; Wanted : Step) is
         begin
            if not Contains (Steps (Item), Wanted) then
               Tooling_Checks.Fail (Name (Item) & " does not run " & Image (Wanted));
            end if;
         end Require_Step;

         procedure Forbid_Step (Item : Subcommand; Unwanted : Step) is
         begin
            if Contains (Steps (Item), Unwanted) then
               Tooling_Checks.Fail (Name (Item) & " must not run " & Image (Unwanted));
            end if;
         end Forbid_Step;

         --  Later runs after Earlier in Item.
         procedure Require_Order (Item : Subcommand; Earlier : Step; Later : Step) is
            List : constant Step_List := Steps (Item);
         begin
            if Position (List, Earlier) = 0 or else Position (List, Later) <= Position (List, Earlier) then
               Tooling_Checks.Fail (Name (Item) & " must run " & Image (Later) & " after " & Image (Earlier));
            end if;
         end Require_Order;

         Release_Check_Steps : constant Step_List := Steps (Release_Check_Command);
         Release_Steps       : constant Step_List := Steps (Release_Command);
      begin
         for Item in Subcommand loop
            Tooling_Checks.Require_Text (Check, "docs/testing.md", "`" & Name (Item) & "`");
            if Steps (Item)'Length = 0 then
               Tooling_Checks.Fail (Name (Item) & " runs nothing");
            end if;

            --  A step that writes files checks nothing; whatever writes
            --  generated files must be followed by the checks of them.
            if Contains (Steps (Item), Generate_Docs) then
               Require_Order (Item, Generate_Docs, Run_Metadata_Checks);
            end if;
            if Contains (Steps (Item), Generate_Package_Manifest) then
               Require_Order (Item, Generate_Package_Manifest, Run_Metadata_Checks);
            end if;
         end loop;

         --  release-check is the whole gate short of a release: every
         --  step but the clean-tree check and the checksums.
         for Item in Step loop
            if Item not in Require_Clean_Source_Tree | Generate_Release_Checksums then
               Require_Step (Release_Check_Command, Item);
            end if;
         end loop;
         Require_Order (Release_Check_Command, Run_Build, Run_Test_Selector_Smoke);
         Require_Order (Release_Check_Command, Run_Build, Run_Staged_Verification);
         Require_Order (Release_Check_Command, Run_Build, Run_Executable_Integration_Smoke);
         Require_Order (Release_Check_Command, Generate_Release_Archive, Run_Metadata_Checks);
         Forbid_Step (Release_Check_Command, Require_Clean_Source_Tree);
         Forbid_Step (Release_Check_Command, Generate_Release_Checksums);

         --  release is release-check on a clean tree that also records
         --  the checksums of what it built.
         if Release_Steps'Length = 0 or else Release_Steps (Release_Steps'First) /= Require_Clean_Source_Tree then
            Tooling_Checks.Fail ("release must check for a clean source tree first");
         end if;
         declare
            Without_Release_Only : Step_List (1 .. Release_Steps'Length);
            Count                : Natural := 0;
         begin
            for Item of Release_Steps loop
               if Item not in Require_Clean_Source_Tree | Generate_Release_Checksums then
                  Count := Count + 1;
                  Without_Release_Only (Count) := Item;
               end if;
            end loop;

            if Without_Release_Only (1 .. Count) /= Release_Check_Steps then
               Tooling_Checks.Fail ("release must run the release-check steps in their order");
            end if;
         end;
         Require_Order (Release_Command, Generate_Release_Archive, Generate_Release_Checksums);
         Require_Order (Release_Command, Run_Build, Generate_Release_Checksums);

         for Item of Steps (Check_Command) loop
            Require_Step (Release_Check_Command, Item);
         end loop;
         Require_Step (Check_Command, Run_Tests);
         Require_Step (Check_Command, Run_Metadata_Checks);
      end Require_Subcommand_Steps;
   begin
      Tooling_Checks.Require_File (Check, "docs/ai.md");
      Tooling_Checks.Require_File (Check, "docs/architecture.md");
      Tooling_Checks.Require_File (Check, "docs/conformance.md");
      Tooling_Checks.Require_File (Check, "docs/development.md");
      Tooling_Checks.Require_File (Check, "docs/portability.md");
      Tooling_Checks.Require_File (Check, "docs/proof-coverage.md");
      Tooling_Checks.Require_File (Check, "docs/release-process.md");
      Tooling_Checks.Require_File (Check, "docs/security.md");
      Tooling_Checks.Require_File (Check, "docs/testing.md");
      Tooling_Checks.Require_Text
        (Check, "docs/release-process.md", "Node 24-compatible checkout action");
      Tooling_Checks.Require_Text
        (Check, "docs/development.md", "Node 24-compatible checkout action");
      Tooling_Checks.Require_Text
        (Check, "docs/portability.md", "Node 24-compatible checkout action");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Repository Map");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Package Map");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Dependency Rules");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Allowed Imports");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Prohibited Imports");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Project Invariants");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Command Workflow");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Test Requirements");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Localization Rules");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Styling Rules");
      Tooling_Checks.Require_Text
        (Check, "docs/ai.md", "Help, root headings, and human diagnostics may be styled");
      Tooling_Checks.Require_Text
        (Check, "docs/ai.md", "stderr terminal status for diagnostics");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Resource Policies");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Completion Criteria");
      Tooling_Checks.Require_Text (Check, "docs/ai.md", "## Rejected Architectures");
      Tooling_Checks.Require_Text
        (Check, "docs/ai.md", "Direct Hostkit use from command algorithms");
      Tooling_Checks.Require_Text
        (Check, "docs/ai.md", "Shell, Python, JavaScript, Make, CMake, or PowerShell project tooling");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`posix_tools_tests`");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`test --suite <name>`");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`test --category unit`");
      Tooling_Checks.Require_Text
        (Check, "docs/testing.md", "`test --category integration`");
      Tooling_Checks.Require_Text
        (Check, "docs/testing.md", "`test --category conformance`");
      Tooling_Checks.Require_Text
        (Check, "docs/testing.md", "`test --category regression`");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`build`");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`check`");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`format-check`");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`docs`");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`prove`");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`package`");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`release-check`");
      Tooling_Checks.Require_Text (Check, "docs/testing.md", "`release`");
      Tooling_Checks.Require_Text
        (Check,
         "docs/testing.md",
         "`posix_tools_tests format-check` scans maintained Ada, Alire/GPR, Markdown, CSV,");
      Require_Subcommand_Steps;
      Require_Synchronized_Version ("alire.toml");
      Require_Synchronized_Version ("common/alire.toml");
      Require_Synchronized_Version ("tests/alire.toml");
      Require_Synchronized_Version ("common/src/posix_tools-version.ads");
      Require_Synchronized_Version ("CHANGELOG.md");
      Require_Synchronized_Version ("generated/manual-index.md");
      Require_Synchronized_Version ("generated/package-manifest.txt");
      --  Only a release writes the release checksums; between releases
      --  the file is the last release's record and names its version.
      if Writes_Release_Checksums then
         Require_Synchronized_Version ("generated/release-checksums.txt");
      end if;
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
