with Ada.Strings.Unbounded;
with Ada.Characters.Handling;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Text.Line_Breaks;
with Posix_Tools.Text.Matching;
with Posix_Tools.Version;
with Project_Tools.Files;
with Project_Tools.Release_Checks;
with Project_Tools.Text;
with Tooling_Support;

package body Metadata_Checks.Packaging is
   use Tooling_Support;

   procedure Run (Writes_Release_Checksums : Boolean) is
      function Count_Prefix_Lines (Text : String; Prefix : String) return Natural is
         Start : Positive := Text'First;
         Count : Natural := 0;
      begin
         if Text = "" then
            return 0;
         end if;

         for I in Text'Range loop
            if Text (I) = Character'Val (10) then
               if I > Start
                 and then Posix_Tools.Text.Matching.Starts_With
                   (Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                      (Text (Start .. I - 1)),
                    Prefix)
               then
                  Count := Count + 1;
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Text'Last
           and then Posix_Tools.Text.Matching.Starts_With
             (Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                (Text (Start .. Text'Last)),
              Prefix)
         then
            Count := Count + 1;
         end if;

         return Count;
      end Count_Prefix_Lines;

      function Count_Nonempty_Lines (Text : String) return Natural is
         Start : Positive := Text'First;
         Count : Natural := 0;
      begin
         if Text = "" then
            return 0;
         end if;

         for I in Text'Range loop
            if Text (I) = Character'Val (10) then
               if I > Start
                 and then Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                   (Text (Start .. I - 1)) /= ""
               then
                  Count := Count + 1;
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Text'Last
           and then Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
             (Text (Start .. Text'Last)) /= ""
         then
            Count := Count + 1;
         end if;

         return Count;
      end Count_Nonempty_Lines;

      function Proof_Unit_Name (Path : String) return String is
         use Ada.Characters.Handling;
         Name_First : Natural := Path'First;
         Name_Last  : Natural := Path'Last;
      begin
         for I in reverse Path'Range loop
            if Path (I) = '/' or else Path (I) = '\' then
               Name_First := I + 1;
               exit;
            end if;
         end loop;

         if Project_Tools.Text.Ends_With (Path, ".ads") then
            Name_Last := Path'Last - 4;
         end if;

         declare
            Name : String := To_Lower (Path (Name_First .. Name_Last));
         begin
            for Ch of Name loop
               if Ch = '-' then
                  Ch := '.';
               end if;
            end loop;
            return Name;
         end;
      end Proof_Unit_Name;

      procedure Require_All_SPARK_Specs_Are_Proof_Targets_And_Documented is
         use Ada.Strings.Unbounded;

         Proof_Driver : constant String :=
           Project_Tools.Files.Read_Raw_File
             (Project_Tools.Files.Join (Root, "tests/src/proof_targets.adb"));
         Proof_Document : constant String :=
           Ada.Characters.Handling.To_Lower
             (Project_Tools.Files.Read_Raw_File
                (Project_Tools.Files.Join (Root, "docs/proof-coverage.md")));
         Source_Roots : constant Project_Tools.Files.Name_List :=
           [To_Unbounded_String ("common/src"),
            To_Unbounded_String ("common/generated")];
      begin
         for Source_Root of Source_Roots loop
            for Path of Project_Tools.Files.List_Tree (Project_Tools.Files.Join (Root, To_String (Source_Root))) loop
               declare
                  File_Path : constant String := To_String (Path);
               begin
                  if Project_Tools.Text.Ends_With (File_Path, ".ads")
                    and then Project_Tools.Files.File_Contains (File_Path, "SPARK_Mode => On")
                  then
                     declare
                        Unit_Name : constant String := Proof_Unit_Name (File_Path);
                     begin
                        if not Posix_Tools.Text.Matching.Contains
                          (Proof_Driver, "To_Unbounded_String (""" & Unit_Name & """)")
                        then
                           Project_Tools.Release_Checks.Fail
                             ("SPARK unit is missing from proof targets: " & Unit_Name);
                        elsif not Posix_Tools.Text.Matching.Contains
                          (Proof_Document, "- `" & Unit_Name & "`")
                        then
                           Project_Tools.Release_Checks.Fail
                             ("SPARK unit is missing from proof coverage docs: " & Unit_Name);
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end loop;
      end Require_All_SPARK_Specs_Are_Proof_Targets_And_Documented;

      function Is_Documented_Non_SPARK_Boundary
        (Unit_Name      : String;
         Proof_Document : String) return Boolean
      is
         use Posix_Tools.Text.Matching;

         function Has_Entry (Name : String) return Boolean is
         begin
            return Contains (Proof_Document, "- `" & Name & "`");
         end Has_Entry;
      begin
         return
           Has_Entry (Unit_Name)
           or else
             (Starts_With (Unit_Name, "posix_tools.commands.")
              and then Has_Entry ("posix_tools.commands.*"))
           or else
             (Starts_With (Unit_Name, "posix_tools.host_adapters")
              and then Has_Entry ("posix_tools.host_adapters.*"));
      end Is_Documented_Non_SPARK_Boundary;

      procedure Require_Non_SPARK_Specs_Are_Documented_Boundaries is
         use Ada.Strings.Unbounded;

         Proof_Document : constant String :=
           Ada.Characters.Handling.To_Lower
             (Project_Tools.Files.Read_Raw_File
                (Project_Tools.Files.Join (Root, "docs/proof-coverage.md")));
         Source_Roots : constant Project_Tools.Files.Name_List :=
           [To_Unbounded_String ("common/src"),
            To_Unbounded_String ("common/generated")];
      begin
         for Source_Root of Source_Roots loop
            for Path of Project_Tools.Files.List_Tree (Project_Tools.Files.Join (Root, To_String (Source_Root))) loop
               declare
                  File_Path : constant String := To_String (Path);
               begin
                  if Project_Tools.Text.Ends_With (File_Path, ".ads")
                    and then not Project_Tools.Files.File_Contains (File_Path, "SPARK_Mode => On")
                  then
                     declare
                        Unit_Name : constant String := Proof_Unit_Name (File_Path);
                     begin
                        if not Is_Documented_Non_SPARK_Boundary (Unit_Name, Proof_Document) then
                           Project_Tools.Release_Checks.Fail
                             ("non-SPARK spec is missing from proof boundary docs: " & Unit_Name);
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end loop;
      end Require_Non_SPARK_Specs_Are_Documented_Boundaries;

      procedure Require_Package_File_List_Matches_Manifest is
         Files_Path : constant String := Project_Tools.Files.Join (Root, "generated/package-files.txt");
         Files      : constant String := Project_Tools.Files.Read_Raw_File (Files_Path);
         Manifest   : constant String :=
           Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"));

         procedure Check_Header is
            Header : constant String :=
              "posix-tools package manifest " & Posix_Tools.Version.Version_String;
            Count  : constant Natural := Count_Exact_Lines (Manifest, Header);
         begin
            if Count = 0 then
               Project_Tools.Release_Checks.Fail ("package manifest header missing or stale");
            elsif Count > 1 then
               Project_Tools.Release_Checks.Fail ("package manifest header is duplicated");
            end if;
         end Check_Header;

         procedure Check_File_List_Line (Relative_Path : String) is
            Expected_Line : constant String := Project_Tools.Release_Checks.Manifest_Line (Root, Relative_Path);
            Count         : constant Natural := Count_Exact_Lines (Manifest, Expected_Line);
         begin
            if Relative_Path = "" then
               null;
            elsif Count = 0 then
               Project_Tools.Release_Checks.Fail
                 ("package manifest missing generated file-list entry " & Relative_Path);
            elsif Count > 1 then
               Project_Tools.Release_Checks.Fail
                 ("package manifest duplicates generated file-list entry " & Relative_Path);
            end if;
         end Check_File_List_Line;

         File_Count         : Natural := 0;
         Manifest_Row_Count : constant Natural := Count_Nonempty_Lines (Manifest);
         Start              : Positive := Files'First;
      begin
         if Files = "" then
            Project_Tools.Release_Checks.Fail ("generated package file list is empty");
         end if;

         Check_Header;

         for I in Files'Range loop
            if Files (I) = Character'Val (10) then
               if I > Start then
                  Check_File_List_Line
                    (Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                       (Files (Start .. I - 1)));
                  File_Count := File_Count + 1;
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Files'Last then
            Check_File_List_Line
              (Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                 (Files (Start .. Files'Last)));
            File_Count := File_Count + 1;
         end if;

         if Manifest_Row_Count = 0 then
            Project_Tools.Release_Checks.Fail ("package manifest is empty");
         elsif Manifest_Row_Count - 1 /= File_Count then
            Project_Tools.Release_Checks.Fail ("package manifest and generated file list have different entry counts");
         end if;
      end Require_Package_File_List_Matches_Manifest;

      procedure Require_Package_File_List_Covers_Fixtures is
         Files  : constant String :=
           Project_Tools.Files.Read_Raw_File
             (Project_Tools.Files.Join (Root, "generated/package-files.txt"));

         procedure Require_Fixture (Relative_Path : String) is
         begin
            if Count_Exact_Lines (Files, Relative_Path) = 0 then
               Project_Tools.Release_Checks.Fail
                 ("package file list missing test fixture " & Relative_Path);
            end if;
         end Require_Fixture;
      begin
         Require_Fixture ("fixtures/invalid-da-utf8.bin");
         Require_Fixture ("fixtures/reg-cat-0001.bin");
         Require_Fixture ("fixtures/reg-cat-first.bin");
         Require_Fixture ("fixtures/reg-cat-later.bin");
         Require_Fixture ("fixtures/reg-cat-second.bin");
         Require_Fixture ("fixtures/reg-end-of-options.txt");
         Require_Fixture ("fixtures/reg-head-counts.txt");
         Require_Fixture ("fixtures/reg-head-default-long.txt");
         Require_Fixture ("fixtures/reg-head-default-short.txt");
         Require_Fixture ("fixtures/reg-head-header-first.txt");
         Require_Fixture ("fixtures/reg-head-header-second.txt");
         Require_Fixture ("fixtures/reg-tail-byte-mode.bin");
         Require_Fixture ("fixtures/reg-tail-byte-spill.bin");
         Require_Fixture ("fixtures/reg-tail-compact.bin");
         Require_Fixture ("fixtures/reg-tail-head-first.txt");
         Require_Fixture ("fixtures/reg-tail-head-second.txt");
         Require_Fixture ("fixtures/reg-tail-line-mode.txt");
         Require_Fixture ("fixtures/reg-tail-plus.txt");
         Require_Fixture ("fixtures/reg-wc-bad-continuation.bin");
         Require_Fixture ("fixtures/reg-wc-default.txt");
         Require_Fixture ("fixtures/reg-wc-first.txt");
         Require_Fixture ("fixtures/reg-wc-invalid.bin");
         Require_Fixture ("fixtures/reg-wc-mixed-invalid.bin");
         Require_Fixture ("fixtures/reg-wc-out-of-range.bin");
         Require_Fixture ("fixtures/reg-wc-overlong.bin");
         Require_Fixture ("fixtures/reg-wc-second.txt");
         Require_Fixture ("fixtures/reg-wc-surrogate.bin");
         Require_Fixture ("fixtures/reg-wc-utf8.txt");
      end Require_Package_File_List_Covers_Fixtures;

      procedure Require_Package_File_List_Covers_Release_Metadata is
         Files : constant String :=
           Project_Tools.Files.Read_Raw_File
             (Project_Tools.Files.Join (Root, "generated/package-files.txt"));

         procedure Require_Packaged (Relative_Path : String) is
         begin
            if Count_Exact_Lines (Files, Relative_Path) = 0 then
               Project_Tools.Release_Checks.Fail
                 ("package file list missing release metadata " & Relative_Path);
            end if;
         end Require_Packaged;
      begin
         Require_Packaged (".github/workflows/ci.yml");
         Require_Packaged ("generated/command_inventory.csv");
         Require_Packaged ("generated/requirements.csv");
         Require_Packaged ("generated/regressions.csv");
         Require_Packaged ("generated/manual-index.md");
         Require_Packaged ("generated/package-files.txt");
      end Require_Package_File_List_Covers_Release_Metadata;

      procedure Require_Release_Checksums_Cover_Inventory is
         Path      : constant String := "generated/release-checksums.txt";
         Checksums : constant String := Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));
         Archive   : constant String := "dist/posix-tools-" & Posix_Tools.Version.Version_String & "-source.7z";

         function Checksum_Line (Label : String; Relative_Path : String) return String is
            Stable_Path : constant String := Project_Tools.Files.Join (Root, Relative_Path);
            Actual_Path : constant String :=
              (if Project_Tools.Files.File_Exists (Stable_Path) then Stable_Path
               elsif Project_Tools.Files.File_Exists (Stable_Path & ".exe") then Stable_Path & ".exe"
               else Stable_Path);
         begin
            return Label & " " & Relative_Path & " fnv1a64="
              & Project_Tools.Release_Checks.FNV1A64 (Actual_Path);
         end Checksum_Line;

         procedure Require_Header is
            Header : constant String :=
              "posix-tools release checksums " & Posix_Tools.Version.Version_String;
            Count  : constant Natural := Count_Exact_Lines (Checksums, Header);
         begin
            if Count = 0 then
               Project_Tools.Release_Checks.Fail ("release checksum header missing or stale");
            elsif Count > 1 then
               Project_Tools.Release_Checks.Fail ("release checksum header is duplicated");
            end if;
         end Require_Header;

         procedure Require_Checksum_Row (Label : String; Relative_Path : String) is
            Stable_Path : constant String := Project_Tools.Files.Join (Root, Relative_Path);
            Actual_Path : constant String :=
              (if Project_Tools.Files.File_Exists (Stable_Path) then Stable_Path
               elsif Project_Tools.Files.File_Exists (Stable_Path & ".exe") then Stable_Path & ".exe"
               else Stable_Path);
            Prefix      : constant String := Label & " " & Relative_Path & " fnv1a64=";
            Count       : Natural;
         begin
            if Project_Tools.Files.File_Exists (Actual_Path) then
               Count := Count_Exact_Lines (Checksums, Checksum_Line (Label, Relative_Path));

               if Count = 0 and then Count_Prefix_Lines (Checksums, Prefix) > 0 then
                  Project_Tools.Release_Checks.Fail ("release checksum entry is stale for " & Relative_Path);
               elsif Count = 0 then
                  Project_Tools.Release_Checks.Fail ("release checksum entry is missing for " & Relative_Path);
               elsif Count > 1 then
                  Project_Tools.Release_Checks.Fail ("release checksum entry is duplicated for " & Relative_Path);
               end if;
            else
               Count := Count_Prefix_Lines (Checksums, Prefix);

               if Count = 0 then
                  Project_Tools.Release_Checks.Fail ("release checksum entry is missing for " & Relative_Path);
               elsif Count > 1 then
                  Project_Tools.Release_Checks.Fail ("release checksum entry is duplicated for " & Relative_Path);
               end if;
            end if;
         end Require_Checksum_Row;

         Expected_Rows : constant Natural := Posix_Tools.Command_Inventory.Command_Count + 4;
      begin
         if Count_Nonempty_Lines (Checksums) /= Expected_Rows then
            Project_Tools.Release_Checks.Fail ("release checksum file has unexpected entry count");
         end if;

         Require_Header;
         Require_Checksum_Row ("manifest", "generated/package-manifest.txt");
         Require_Checksum_Row ("archive", Archive);

         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            Require_Checksum_Row
              ("executable",
               "tools/" & Posix_Tools.Command_Inventory.Executable (I)
               & "/bin/" & Posix_Tools.Command_Inventory.Executable (I));
         end loop;

         Require_Checksum_Row ("executable", "bin/posix-tools");
      end Require_Release_Checksums_Cover_Inventory;
   begin
      Project_Tools.Release_Checks.Require_Directory (Check, "generated/man");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/man/posix-tools.1", ".TH posix-tools 1");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "generated/man/posix-tools.1");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/regressions.csv", "REG-STDIN-0001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/regressions.csv", "REG-STDOUT-0001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/regressions.csv", "REG-WC-0006");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/regressions.csv", "REG-WC-0007");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/command_inventory.csv", "documentation_path");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "INVENTORY-CURRENT-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "INVENTORY-STRUCTURE-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "REPOSITORY-EOL-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "CONFORMANCE-IMPLEMENTATION-REFS-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "CONFORMANCE-TEST-REFS-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "REGRESSION-METADATA-001");
      Project_Tools.Release_Checks.Require_Text (Check, ".gitattributes", "*.csv text eol=lf");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/command_inventory.csv", "tools/tail/posix_tools_tail.gpr");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/command_inventory.csv", "docs/commands/wc.md");
      if Writes_Release_Checksums then
         Project_Tools.Release_Checks.Require_Text
           (Check, "generated/release-checksums.txt", "manifest generated/package-manifest.txt fnv1a64=");
         Project_Tools.Release_Checks.Require_Text
           (Check, "generated/release-checksums.txt", "archive dist/posix-tools-");
         Project_Tools.Release_Checks.Require_Text
           (Check, "generated/release-checksums.txt", "executable bin/posix-tools fnv1a64=");
      end if;
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "platform-aware executable artifact lookup");
      Require_All_SPARK_Specs_Are_Proof_Targets_And_Documented;
      Require_Non_SPARK_Specs_Are_Documented_Boundaries;
      if Writes_Release_Checksums then
         Require_Release_Checksums_Cover_Inventory;
      end if;

      Project_Tools.Release_Checks.Require_Text (Check, ".gitignore", "/dist/");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "README.md");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "generated/package-files.txt");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "alire.toml");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "common/alire.toml");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "common/posix_tools_proof.gpr");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "docs/architecture.md");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "docs/conformance.md");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "docs/testing.md");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "src/posix-tools.adb");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
         Root,
         "common/src/posix_tools-version.ads");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
         Root,
         "common/src/posix_tools-commands-cat.adb");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
         Root,
         "common/src/posix_tools-streams-counting.adb");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
         Root,
         "common/messages/posix_tools.catalog");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "tests/alire.toml");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
         Root,
         "tests/src/posix_tools_tests.adb");
      Require_Package_File_List_Matches_Manifest;
      Require_Package_File_List_Covers_Fixtures;
      Require_Package_File_List_Covers_Release_Metadata;
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
         Root,
         "tests/src/test_contexts.ads");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Project_Tools.Release_Checks.Require_Manifest_Entry
           (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
            Root,
            Posix_Tools.Command_Inventory.Manifest_Path (I));
         Project_Tools.Release_Checks.Require_Manifest_Entry
           (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
            Root,
            Posix_Tools.Command_Inventory.Project_File_Path (I));
         Project_Tools.Release_Checks.Require_Manifest_Entry
           (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
            Root,
            Posix_Tools.Command_Inventory.Documentation_Path (I));
         Project_Tools.Release_Checks.Require_Manifest_Entry
           (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
            Root,
            Posix_Tools.Command_Inventory.Wrapper_Path (I));
         Project_Tools.Release_Checks.Require_Manifest_Entry
           (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
            Root,
            "generated/man/" & Posix_Tools.Command_Inventory.Executable (I) & ".1");
         Project_Tools.Release_Checks.Require_Text
           (Check,
            "generated/man/" & Posix_Tools.Command_Inventory.Executable (I) & ".1",
            ".TH " & Posix_Tools.Command_Inventory.Executable (I) & " 1");
         if Writes_Release_Checksums then
            Project_Tools.Release_Checks.Require_Text
              (Check,
               "generated/release-checksums.txt",
               "executable tools/" & Posix_Tools.Command_Inventory.Executable (I)
               & "/bin/" & Posix_Tools.Command_Inventory.Executable (I) & " fnv1a64=");
         end if;
      end loop;
      Project_Tools.Release_Checks.Require_Text (Check, "README.md", "posix_tools");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Project_Tools.Release_Checks.Require_Text
           (Check, "README.md", "- `" & Posix_Tools.Command_Inventory.Executable (I) & "`");
      end loop;
      Project_Tools.Release_Checks.Require_Text (Check, "README.md", "- `posix-tools`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "DOCS-README-INVENTORY-001");
   end Run;
end Metadata_Checks.Packaging;
