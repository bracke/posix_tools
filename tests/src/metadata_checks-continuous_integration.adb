with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Posix_Tools.Text.Line_Breaks;
with Project_Tools.Files;
with Tooling_Checks;
with Tooling_Support;

package body Metadata_Checks.Continuous_Integration is
   use Ada.Strings.Unbounded;
   use Tooling_Support;

   package Name_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);

   Workflow : constant String := ".github/workflows/ci.yml";

   --  Path joined onto Dir with "." and ".." resolved; both are relative to
   --  the project root, and a result outside it starts with "../".
   function Resolve (Dir : String; Path : String) return String is
      Parts  : array (1 .. 64) of Unbounded_String;
      Count  : Natural := 0;
      Text   : constant String := (if Dir = "" then Path else Dir & "/" & Path);
      Start  : Positive := Text'First;
      Result : Unbounded_String;

      procedure Take (Part : String) is
      begin
         if Part = "" or else Part = "." then
            null;
         elsif Part = ".." and then Count > 0 and then Parts (Count) /= ".." then
            Count := Count - 1;
         else
            Count := Count + 1;
            Parts (Count) := To_Unbounded_String (Part);
         end if;
      end Take;
   begin
      for I in Text'Range loop
         if Text (I) = '/' then
            Take (Text (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;
      Take (Text (Start .. Text'Last));

      for I in 1 .. Count loop
         Append (Result, (if I = 1 then "" else "/") & Parts (I));
      end loop;

      return To_String (Result);
   end Resolve;

   function Directory_Of (Path : String) return String is
      Last : constant Natural := Ada.Strings.Fixed.Index (Path, "/", Ada.Strings.Backward);
   begin
      return (if Last = 0 then "" else Path (Path'First .. Last - 1));
   end Directory_Of;

   --  The repositories beside this one that the crates' path pins reach,
   --  followed through the pinned manifests the checkouts hold.
   function Sibling_Checkouts return Name_Sets.Set is
      Siblings : Name_Sets.Set;
      Seen     : Name_Sets.Set;

      procedure Visit (Manifest : String) is
         Full : constant String := Project_Tools.Files.Join (Root, Manifest);
      begin
         if Seen.Contains (Manifest) or else not Project_Tools.Files.File_Exists (Full) then
            return;
         end if;
         Seen.Insert (Manifest);

         declare
            Content : constant String := Project_Tools.Files.Read_Raw_File (Full);
            Marker  : constant String := "path = """;
            Start   : Positive := Content'First;
         begin
            for I in Content'Range loop
               if Content (I) = Character'Val (10) or else I = Content'Last then
                  declare
                     Line  : constant String :=
                       Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                         (Content (Start .. (if Content (I) = Character'Val (10) then I - 1 else I)));
                     At_Marker : constant Natural := Ada.Strings.Fixed.Index (Line, Marker);
                  begin
                     if At_Marker /= 0 then
                        declare
                           From  : constant Positive := At_Marker + Marker'Length;
                           Close : constant Natural := Ada.Strings.Fixed.Index (Line (From .. Line'Last), """");
                           Pin   : constant String :=
                             Resolve (Directory_Of (Manifest), Line (From .. Close - 1));
                        begin
                           if Close = 0 then
                              Tooling_Checks.Fail (Manifest & " has an unterminated path pin");
                           end if;

                           if Pin'Length > 3 and then Pin (Pin'First .. Pin'First + 2) = "../" then
                              declare
                                 Rest  : constant String := Pin (Pin'First + 3 .. Pin'Last);
                                 Slash : constant Natural := Ada.Strings.Fixed.Index (Rest, "/");
                              begin
                                 Siblings.Include (if Slash = 0 then Rest else Rest (Rest'First .. Slash - 1));
                              end;
                           end if;

                           Visit (Pin & "/alire.toml");
                        end;
                     end if;
                  end;
                  Start := I + 1;
               end if;
            end loop;
         end;
      end Visit;

      Manifests : constant Project_Tools.Files.Path_List :=
        Project_Tools.Files.List_Tree
          (Root,
           Name_Pattern => "alire.toml",
           Skip_Entries =>
             [To_Unbounded_String ("alire"),
              To_Unbounded_String ("bin"),
              To_Unbounded_String ("config"),
              To_Unbounded_String ("obj"),
              To_Unbounded_String (".git")]);
   begin
      for Manifest of Manifests loop
         declare
            Path : constant String := To_String (Manifest);
         begin
            Visit
              (if Path'Length > Root'Length + 1
                 and then Path (Path'First .. Path'First + Root'Length) = Root & "/"
               then Path (Path'First + Root'Length + 1 .. Path'Last)
               else Path);
         end;
      end loop;

      return Siblings;
   end Sibling_Checkouts;

   procedure Run is
      Siblings : constant Name_Sets.Set := Sibling_Checkouts;
   begin
      if Siblings.Is_Empty then
         Tooling_Checks.Fail ("no sibling checkouts found in the crates' path pins");
      end if;

      --  Every repository a path pin reaches is checked out beside this one.
      for Name of Siblings loop
         Require_Exact_Line (Workflow, "          repository: bracke/" & Name, "checkout of " & Name);
         Require_Exact_Line (Workflow, "          path: " & Name, "checkout path of " & Name);
      end loop;
      Require_Exact_Line (Workflow, "          path: posix_tools", "checkout path of posix_tools");

      --  The steps that make the gate, each once and in the order that
      --  makes them work: committed line endings for every checkout and only
      --  for them, the tooling built before the gate runs, and the drift
      --  check after the gate has regenerated what it checks.
      declare
         Keep_Endings    : constant String := "        run: git config --global core.autocrlf false";
         Checkout        : constant String := "        uses: actions/checkout@v7";
         Restore_Endings : constant String := "        run: git config --global --unset core.autocrlf || true";
         Build           : constant String := "        run: alr -n build";
         Install_Prover  : constant String := "            if alr -n install gnatprove=15.1.0; then";
         Gate            : constant String := "        run: ${{ matrix.test_runner }} release-check";
         Drift_Check     : constant String :=
           "        run: test -z ""$(git status --porcelain)"" || { git status; git diff; exit 1; }";
      begin
         Require_Exact_Line (Workflow, Keep_Endings, "line ending setting before checkout");
         Require_Exact_Line (Workflow, Restore_Endings, "line ending setting after checkout");
         Require_Exact_Line (Workflow, Build, "tooling build step");
         Require_Exact_Line (Workflow, Install_Prover, "pinned GNATprove install");
         Require_Exact_Line (Workflow, Gate, "release gate step");
         Require_Exact_Line (Workflow, Drift_Check, "generated file drift check");
         Require_Line_Order (Workflow, Keep_Endings, Checkout);
         Require_Line_Order (Workflow, Checkout, Restore_Endings);
         Require_Line_Order (Workflow, Restore_Endings, Build);
         Require_Line_Order (Workflow, Build, Gate);
         Require_Line_Order (Workflow, Install_Prover, Gate);
         Require_Line_Order (Workflow, Gate, Drift_Check);
      end;

      Tooling_Checks.Require_Text (Check, Workflow, "ubuntu-latest");
      Tooling_Checks.Require_Text (Check, Workflow, "macos-15-intel");
      Tooling_Checks.Require_Text (Check, Workflow, "windows-latest");
      Tooling_Checks.Require_Text (Check, Workflow, "pull_request:");
      Tooling_Checks.Require_Text (Check, Workflow, "workflow_dispatch:");
      Tooling_Checks.Require_Text (Check, Workflow, "contents: read");
      Tooling_Checks.Require_Text (Check, Workflow, "timeout-minutes: 60");
      Tooling_Checks.Require_Text (Check, Workflow, "fail-fast: false");
      Forbid_Text (Workflow, "actions/checkout@v4", "CI workflow must use Node 24 compatible checkout");
      Forbid_Text (Workflow, "actions/setup-node@v4", "CI workflow must not pin Node 20 setup actions");
      Forbid_Text (Workflow, "actions/cache/restore@v4", "CI workflow must not pin Node 20 cache actions");
      Tooling_Checks.Require_Text (Check, Workflow, "alire-project/setup-alire@v6");
      Forbid_Text
        (Workflow,
         "alire-project/setup-alire@v6.0.0",
         "CI workflow must use setup-alire v6 branch with Node 24 internals");
      Forbid_Text (Workflow, "alire-project/setup-alire@v5", "CI workflow must use current setup-alire");
      Tooling_Checks.Require_Text (Check, Workflow, "working-directory: posix_tools/tests");
      Tooling_Checks.Require_Text (Check, Workflow, "posix_tools_tests.exe");
      Tooling_Checks.Require_Text (Check, Workflow, "GITHUB_PATH");
      Tooling_Checks.Require_Text (Check, Workflow, "cygpath -w");
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
