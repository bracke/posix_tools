with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Package_Entries;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Version;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;
with Tooling_Checks;
with Tooling_Support;

package body Release_Artifacts is
   use Tooling_Support;

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

   procedure Generate_Release_Archive is
      Archive  : constant String := Tooling_Support.Release_Archive_Path;
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
      Add_File ("archive", Tooling_Support.Release_Archive_Path);

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
end Release_Artifacts;
