with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with All_Suites;
with AUnit.Options;
with AUnit.Reporter.Text;
with AUnit.Run;
with AUnit;
with Build_Checks;
with Conformance_Checks;
with Format_Checks;
with Integration_Smoke;
with Metadata_Checks.Command_Inventory;
with Metadata_Checks.Continuous_Integration;
with Metadata_Checks.Dependencies;
with Metadata_Checks.Manifests;
with Metadata_Checks.Packaging;
with Metadata_Checks.Requirements;
with Metadata_Checks.Source_Rules;
with Metadata_Checks.Test_Coverage;
with Metadata_Checks.Tooling_Docs;
with Package_Entries;
with Posix_Tools.Command_Inventory;
with Ada.Real_Time;
with Posix_Tools.Host_Adapters.Executables;
with Posix_Tools.Host_Adapters.Processes;
with Test_Support;
with Posix_Tools.Version;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;
with Tooling_Checks;
with Proof_Targets;
with Selector_Smoke;
with Suite_Filters;
with Tooling_Steps;
with Tooling_Support;

procedure Posix_Tools_Tests is
   use Tooling_Support;

   --  Test_Runner exits 0 however many assertions failed; Run_Tests takes
   --  the status and fails the process on anything but success.
   function Runner is new AUnit.Run.Test_Runner_With_Status (All_Suites.Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Options  : AUnit.Options.AUnit_Options :=
     (Global_Timer     => False,
      Test_Case_Timer  => False,
      Report_Successes => True,
      Filter           => null);
   Filter : aliased Suite_Filters.Filter;

   Command : constant String :=
     (if Ada.Command_Line.Argument_Count = 0 then "test" else Ada.Command_Line.Argument (1));
   Invalid_Usage : exception;

   --  Only a release writes generated/release-checksums.txt, from the
   --  binaries it built; between releases the committed file is that
   --  release's record, and every local build would make it stale. So only
   --  a release checks what the file holds.
   Writes_Release_Checksums : constant Boolean :=
     Tooling_Steps.Is_Subcommand (Command)
     and then Tooling_Steps.Contains
       (Tooling_Steps.Steps (Tooling_Steps.Lookup (Command)),
        Tooling_Steps.Generate_Release_Checksums);

   procedure Run_Metadata_Checks is
   begin
      Metadata_Checks.Manifests.Run;
      Metadata_Checks.Tooling_Docs.Run (Writes_Release_Checksums);
      Metadata_Checks.Test_Coverage.Run;
      Metadata_Checks.Source_Rules.Run;
      Metadata_Checks.Dependencies.Run;
      Metadata_Checks.Command_Inventory.Run;
      Metadata_Checks.Requirements.Run;
      Metadata_Checks.Continuous_Integration.Run;
      Metadata_Checks.Packaging.Run (Writes_Release_Checksums);
      Ada.Text_IO.Put_Line ("metadata checks passed");
   end Run_Metadata_Checks;

   procedure Generate_Docs is
      Base    : constant String := Root;
      Man_Dir : constant String := Project_Tools.Files.Join (Base, "generated/man");

      procedure Generate_Command_Inventory is
      begin
         Project_Tools.Files.Write_Raw_File
           (Project_Tools.Files.Join (Base, "generated/command_inventory.csv"),
            Command_Inventory_Csv);
      end Generate_Command_Inventory;

      procedure Generate_Manpage (Index : Positive) is
         Command : constant String := Posix_Tools.Command_Inventory.Executable (Index);
      begin
         Project_Tools.Files.Write_Raw_File
           (Project_Tools.Files.Join (Man_Dir, Command & ".1"), Command_Manpage (Index));
      end Generate_Manpage;

      procedure Generate_Root_Manpage is
      begin
         Project_Tools.Files.Write_Raw_File
           (Project_Tools.Files.Join (Man_Dir, "posix-tools.1"), Root_Manpage);
      end Generate_Root_Manpage;
   begin
      if not Ada.Directories.Exists (Man_Dir) then
         Ada.Directories.Create_Directory (Man_Dir);
      end if;

      Generate_Command_Inventory;
      Generate_Root_Manpage;
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Generate_Manpage (I);
      end loop;

      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Base, "generated/manual-index.md"), Manual_Index);
      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Base, "docs/commands/index.md"), Command_Reference_Index);
      Ada.Text_IO.Put_Line ("docs/commands/index.md");
      Ada.Text_IO.Put_Line ("generated/command_inventory.csv");
      Ada.Text_IO.Put_Line ("generated/manual-index.md");
      Ada.Text_IO.Put_Line ("generated/man/*.1");
   end Generate_Docs;

   procedure Generate_Package_Manifest is
      use Ada.Strings.Unbounded;
      Content : Unbounded_String;
      Files   : Unbounded_String;
      Base    : constant String := Root;

      procedure Add_Entry (Relative_Path : String) is
      begin
         Append (Files, Relative_Path & Character'Val (10));
         Append
           (Content,
            Project_Tools.Release_Checks.Manifest_Line (Base, Relative_Path)
            & Character'Val (10));
      end Add_Entry;
   begin
      Append
        (Content,
         "posix-tools package manifest " & Posix_Tools.Version.Version_String
         & Character'Val (10));
      declare
         procedure Append_Entries is new Package_Entries (Add_Entry);
      begin
         Append_Entries;
      end;

      Append (Files, "generated/package-files.txt" & Character'Val (10));
      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Base, "generated/package-files.txt"), To_String (Files));
      Ada.Text_IO.Put_Line ("generated/package-files.txt");
      Append
        (Content,
         Project_Tools.Release_Checks.Manifest_Line (Base, "generated/package-files.txt")
         & Character'Val (10));
      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Base, "generated/package-manifest.txt"), To_String (Content));
      Ada.Text_IO.Put_Line ("generated/package-manifest.txt");
   end Generate_Package_Manifest;

   function Release_Archive_Path return String is
   begin
      return "dist/posix-tools-" & Posix_Tools.Version.Version_String & "-source.7z";
   end Release_Archive_Path;

   procedure Generate_Release_Archive is
      Archive  : constant String := Release_Archive_Path;
      Seven_Z  : constant String := Project_Tools.Processes.Locate_Command ("7z");
      Seven_Zz : constant String := Project_Tools.Processes.Locate_Command ("7zz");
      Archiver : constant String := (if Seven_Z /= "" then Seven_Z else Seven_Zz);
      Output   : Ada.Strings.Unbounded.Unbounded_String;
      Status   : Integer;
   begin
      if Archiver = "" then
         Tooling_Checks.Fail ("7z-compatible command not found for release archive generation");
      end if;

      if not Project_Tools.Files.Directory_Exists (Project_Tools.Files.Join (Root, "dist")) then
         Ada.Directories.Create_Directory (Project_Tools.Files.Join (Root, "dist"));
      end if;

      Project_Tools.Files.Delete_File_If_Present (Project_Tools.Files.Join (Root, Archive));
      Status :=
        Project_Tools.Processes.Run_Status
           (Label   => "create release archive",
            Dir     => Root,
            Program => Archiver,
            Args    => Project_Tools.Processes.Arguments
              ([Project_Tools.Processes.Argument ("a"),
                Project_Tools.Processes.Argument ("-t7z"),
                Project_Tools.Processes.Argument ("-mx=9"),
                Project_Tools.Processes.Argument ("-mmt=off"),
                Project_Tools.Processes.Argument ("-mtm=off"),
                Project_Tools.Processes.Argument (Archive),
                Project_Tools.Processes.Argument ("@generated/package-files.txt")]),
            Output  => Output,
            Quiet   => True);

      if Status /= 0 then
         Tooling_Checks.Fail
           ("release archive generation failed with status" & Integer'Image (Status));
      elsif not Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Archive)) then
         Tooling_Checks.Fail ("release archive was not created");
      end if;

      Status :=
        Project_Tools.Processes.Run_Status
           (Label   => "test release archive",
            Dir     => Root,
            Program => Archiver,
            Args    => Project_Tools.Processes.Arguments
              ([Project_Tools.Processes.Argument ("t"),
                Project_Tools.Processes.Argument (Archive)]),
            Output  => Output,
            Quiet   => True);

      if Status /= 0 then
         Tooling_Checks.Fail
           ("release archive integrity test failed with status" & Integer'Image (Status));
      end if;

      Ada.Text_IO.Put_Line (Archive);
   end Generate_Release_Archive;

   procedure Generate_Release_Checksums is
      use Ada.Strings.Unbounded;
      Content : Unbounded_String;
      Base    : constant String := Root;

      procedure Add_File
        (Label         : String;
         Display_Path  : String;
         Artifact_Path : String)
      is
      begin
         Append
           (Content,
            Label & " " & Display_Path
            & " fnv1a64=" & Project_Tools.Release_Checks.FNV1A64 (Artifact_Path)
            & Character'Val (10));
      end Add_File;

      procedure Add_File (Label : String; Path : String) is
      begin
         Add_File (Label, Path, Project_Tools.Files.Join (Base, Path));
      end Add_File;
   begin
      Append
        (Content,
         "posix-tools release checksums " & Posix_Tools.Version.Version_String
         & Character'Val (10));
      Add_File ("manifest", "generated/package-manifest.txt");
      Add_File ("archive", Release_Archive_Path);

      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Executable   : constant String := Posix_Tools.Command_Inventory.Executable (I);
            Display_Path : constant String := "tools/" & Executable & "/bin/" & Executable;
         begin
            Add_File ("executable", Display_Path, Built_Command_Path (Executable));
         end;
      end loop;

      Add_File ("executable", "bin/posix-tools", Built_Root_Path);

      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Base, "generated/release-checksums.txt"), To_String (Content));
      Ada.Text_IO.Put_Line ("generated/release-checksums.txt");
   end Generate_Release_Checksums;

   function Prove_Args
     (Unit_Name : String;
      Mode      : String;
      Level     : String := "1")
      return Project_Tools.Processes.Argument_Vectors.Vector is
   begin
      return Project_Tools.Processes.Arguments
        ([Project_Tools.Processes.Argument ("-P"),
          Project_Tools.Processes.Argument ("posix_tools_proof.gpr"),
          Project_Tools.Processes.Argument ("-u"),
          Project_Tools.Processes.Argument (Unit_Name),
          Project_Tools.Processes.Argument ("--mode=" & Mode),
          Project_Tools.Processes.Argument ("--level=" & Level),
          Project_Tools.Processes.Argument ("--checks-as-errors=on"),
          Project_Tools.Processes.Argument ("--warnings=error"),
          Project_Tools.Processes.Argument ("--prover=z3")]);
   end Prove_Args;

   procedure Prove_Target
     (Gnatprove : String;
      Label     : String;
      Unit_Name : String;
      Mode      : String;
      Level     : String := "1")
   is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          (Label   => Label,
           Dir     => Project_Tools.Files.Join (Root, "common"),
           Program => Gnatprove,
           Args    => Prove_Args (Unit_Name, Mode, Level));
   begin
      if Status /= 0 then
         Tooling_Checks.Fail
           ("proof target " & Unit_Name & " failed in " & Mode & " mode");
      end if;
   end Prove_Target;

   procedure Run_Proof_Checks is
      procedure Run_Targets is new Proof_Targets (Prove_Target);
      Gnatprove : constant String := Project_Tools.Processes.Locate_Command ("gnatprove");
   begin
      if Gnatprove = "" then
         Tooling_Checks.Fail
           ("gnatprove command not found for proof checks; install it with `alr -n install gnatprove`");
      end if;

      Run_Targets (Gnatprove);
      Ada.Text_IO.Put_Line ("proof checks passed");
   end Run_Proof_Checks;

   procedure Require_Clean_Source_Tree is
      use Ada.Strings.Unbounded;
      Git : constant String := Project_Tools.Processes.Locate_Command ("git");
      Result : Project_Tools.Processes.Captured_Process;
   begin
      if Git = "" then
         Tooling_Checks.Fail ("git command not found for release clean-tree check");
      end if;

      Result :=
        Project_Tools.Processes.Capture
          (Label   => "check clean source tree",
           Dir     => Root,
           Program => Git,
           Args    => Project_Tools.Processes.Arguments
             ([Project_Tools.Processes.Argument ("status"),
               Project_Tools.Processes.Argument ("--porcelain")]));

      if Result.Status /= 0 then
         Tooling_Checks.Fail ("git status failed during release clean-tree check");
      elsif To_String (Result.Output) /= "" then
         Tooling_Checks.Fail ("release requires a clean source tree");
      end if;
   end Require_Clean_Source_Tree;

   procedure Run_Staged_Verification is
      use Ada.Strings.Unbounded;

      function Identity_Diagnostic
        (Executable : String;
         Program    : String) return String
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture
             (Label   => "identity diagnostic " & Executable,
              Dir     => Root,
              Program => Program,
              Args    => Project_Tools.Processes.Arguments
                ([Project_Tools.Processes.Argument ("--posix-tools-identify")]),
              Quiet   => True);
         --  Run it once more with a long deadline and a stopwatch, to tell a
         --  program that hangs from a slow one and either from a crash: on
         --  Windows a crash exits with a large NTSTATUS code.
         Started     : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Exit_Status : Integer;
         Timed_Out   : Boolean;
         Ran         : constant Boolean :=
           Posix_Tools.Host_Adapters.Processes.Run_With_Timeout
             (Program, Test_Support.One_Arg ("--posix-tools-identify"), 30_000, Exit_Status, Timed_Out);
         Elapsed_Ms  : constant Integer :=
           Integer (Ada.Real_Time.To_Duration (Ada.Real_Time."-" (Ada.Real_Time.Clock, Started)) * 1000.0);
      begin
         return
           " path=""" & Program & """"
           & " direct-status=" & Integer'Image (Captured.Status)
           & " direct-output=""" & Display_Output (To_String (Captured.Output)) & """"
           & " rerun-started=" & Boolean'Image (Ran)
           & " rerun-timed-out=" & Boolean'Image (Timed_Out)
           & " rerun-status=" & Integer'Image (Exit_Status)
           & " rerun-ms=" & Integer'Image (Elapsed_Ms);
      end Identity_Diagnostic;
   begin
      declare
         Program : constant String := Built_Root_Path;
         Status : constant String :=
           Posix_Tools.Host_Adapters.Executables.Verify_Identity_At_Path
             ("posix-tools", Program);
      begin
         if Status /= "ok" then
            Tooling_Checks.Fail
              ("staged verification failed for posix-tools: " & Status
               & Identity_Diagnostic ("posix-tools", Program));
         end if;
      end;

      declare
         Status : constant String :=
           Posix_Tools.Host_Adapters.Executables.Verify_Identity_At_Path
             ("posix-tools", Built_Root_Path, "0.0.0");
      begin
         if Status /= "wrong version" then
            Tooling_Checks.Fail
              ("staged verification wrong-version classification failed for posix-tools: " & Status);
         end if;
      end;

      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Executable : constant String := Posix_Tools.Command_Inventory.Executable (I);
            Program    : constant String := Built_Command_Path (Executable);
            Status     : constant String :=
              Posix_Tools.Host_Adapters.Executables.Verify_Identity_At_Path
                (Executable, Program);
         begin
            if Status /= "ok" then
               Tooling_Checks.Fail
                 ("staged verification failed for " & Executable & ": " & Status
                  & Identity_Diagnostic (Executable, Program));
            end if;
         end;
      end loop;

      Ada.Text_IO.Put_Line ("staged verification checks passed");
   end Run_Staged_Verification;

   --  Point Filter at the tests --suite Name selects: a test group by its
   --  prefix, or one command's tests by its whole name, so that tr does
   --  not also select true.
   procedure Select_Suite (Name : String) is
   begin
      if Name = "basic" or else Name = "common" then
         Suite_Filters.Set (Filter, "basic:", Whole_Name => False);
      elsif Name = "streams" then
         Suite_Filters.Set (Filter, "streams:", Whole_Name => False);
      elsif Name = "regression" then
         Suite_Filters.Set (Filter, "regression:", Whole_Name => False);
      elsif Name = "locale" then
         Suite_Filters.Set (Filter, "locale:", Whole_Name => False);
      elsif Name = "presentation" then
         Suite_Filters.Set (Filter, "presentation:", Whole_Name => False);
      elsif Name = "property" then
         Suite_Filters.Set (Filter, "property:", Whole_Name => False);
      elsif Name = "command" or else Name = "commands" then
         Suite_Filters.Set (Filter, "command:", Whole_Name => False);
      elsif Name = "root" or else Name = "posix-tools" then
         Suite_Filters.Set (Filter, "command:root", Whole_Name => True);
      elsif Posix_Tools.Command_Inventory.Contains_Executable (Name) then
         Suite_Filters.Set (Filter, "command:" & Name, Whole_Name => True);
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "posix_tools_tests: suite '" & Name & "' has no registered AUnit tests yet");
         raise Invalid_Usage;
      end if;
   end Select_Suite;

   procedure Select_Category (Name : String) is
   begin
      if Name = "unit" then
         Suite_Filters.Set (Filter, "", Whole_Name => False);
      elsif Name = "integration" then
         Suite_Filters.Set (Filter, "command:root", Whole_Name => True);
      elsif Name = "conformance" then
         Suite_Filters.Set (Filter, "basic:command inventory", Whole_Name => False);
      elsif Name = "regression" then
         Suite_Filters.Set (Filter, "regression:", Whole_Name => False);
      elsif Name = "locale" then
         Suite_Filters.Set (Filter, "locale:", Whole_Name => False);
      elsif Name = "presentation" then
         Suite_Filters.Set (Filter, "presentation:", Whole_Name => False);
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "posix_tools_tests: category '" & Name & "' has no registered AUnit tests yet");
         raise Invalid_Usage;
      end if;
   end Select_Category;

   --  Apply the test command's selectors, the last one winning.
   procedure Select_Tests is
      I : Positive := 2;
   begin
      if Command /= "test" then
         return;
      end if;

      while I <= Ada.Command_Line.Argument_Count loop
         if Ada.Command_Line.Argument (I) = "--suite"
           and then I < Ada.Command_Line.Argument_Count
         then
            Select_Suite (Ada.Command_Line.Argument (I + 1));
            I := I + 2;
         elsif Ada.Command_Line.Argument (I) = "--category"
           and then I < Ada.Command_Line.Argument_Count
         then
            Select_Category (Ada.Command_Line.Argument (I + 1));
            I := I + 2;
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "posix_tools_tests: invalid test option '" & Ada.Command_Line.Argument (I) & "'");
            raise Invalid_Usage;
         end if;
      end loop;
   end Select_Tests;

   procedure Run_Tests is
      use type AUnit.Status;
   begin
      Select_Tests;
      Options.Filter := Filter'Unchecked_Access;

      if Runner (Reporter, Options) /= AUnit.Success then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   end Run_Tests;

   procedure Run_Step (Item : Tooling_Steps.Step) is
      use Tooling_Steps;
   begin
      case Item is
         when Require_Clean_Source_Tree        => Posix_Tools_Tests.Require_Clean_Source_Tree;
         when Generate_Docs                    => Posix_Tools_Tests.Generate_Docs;
         when Generate_Package_Manifest        => Posix_Tools_Tests.Generate_Package_Manifest;
         when Run_Build                        => Build_Checks.Run (Root);
         when Run_Test_Selector_Smoke          => Selector_Smoke.Run;
         when Run_Staged_Verification          => Posix_Tools_Tests.Run_Staged_Verification;
         when Run_Executable_Integration_Smoke => Integration_Smoke.Run;
         when Generate_Release_Archive         => Posix_Tools_Tests.Generate_Release_Archive;
         when Generate_Release_Checksums       => Posix_Tools_Tests.Generate_Release_Checksums;
         when Run_Metadata_Checks              => Posix_Tools_Tests.Run_Metadata_Checks;
         when Run_Format_Checks                => Format_Checks.Run (Root);
         when Run_Conformance_Checks           => Conformance_Checks.Run;
         when Run_Proof_Checks                 => Posix_Tools_Tests.Run_Proof_Checks;
         when Run_Tests                        => Posix_Tools_Tests.Run_Tests;
      end case;
   end Run_Step;
begin
   if not Tooling_Steps.Is_Subcommand (Command) then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "posix_tools_tests: unknown command '" & Command & "'");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;

   declare
      use Tooling_Steps;
      Item : constant Subcommand := Lookup (Command);
   begin
      for Each of Steps (Item) loop
         Run_Step (Each);
      end loop;

      if Item not in Test_Command | Check_Command | Release_Check_Command then
         Ada.Text_IO.Put_Line (Command & ": completed by Ada project_tools driver");
      end if;
   end;
exception
   when Invalid_Usage =>
      Ada.Command_Line.Set_Exit_Status (2);
   when Tooling_Checks.Check_Failed =>
      --  The check has said what failed.
      Ada.Command_Line.Set_Exit_Status (1);
   when Occurrence : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "posix_tools_tests: internal tooling failure");
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         Ada.Exceptions.Exception_Information (Occurrence));
      Ada.Command_Line.Set_Exit_Status (125);
end Posix_Tools_Tests;
