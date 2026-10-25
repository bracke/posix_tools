with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with All_Suites;
with AUnit.Options;
with AUnit.Reporter.Text;
with AUnit.Run;
with AUnit.Test_Filters;
with AUnit;
with Build_Checks;
with Format_Checks;
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
with Posix_Tools.Host_Adapters.Executables;
with Posix_Tools.Paths;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Line_Breaks;
with Posix_Tools.Text.Matching;
with Posix_Tools.Version;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;
with Project_Tools.Text;
with Proof_Targets;
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
   Name_Filter : aliased AUnit.Test_Filters.Name_Filter;

   Command : constant String :=
     (if Ada.Command_Line.Argument_Count = 0 then "test" else Ada.Command_Line.Argument (1));
   Invalid_Usage : exception;

   --  Only a release writes generated/release-checksums.txt, from the
   --  binaries it built; between releases the committed file is that
   --  release's record, and every local build would make it stale. So only
   --  a release checks what the file holds.
   Writes_Release_Checksums : constant Boolean := Command = "release";

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
      use Ada.Strings.Unbounded;
      Content : Unbounded_String;
      Base    : constant String := Root;
      Man_Dir : constant String := Project_Tools.Files.Join (Base, "generated/man");

      function Boolean_Text (Value : Boolean) return String is
      begin
         if Value then
            return "true";
         else
            return "false";
         end if;
      end Boolean_Text;

      function Render_Command_Inventory return String is
         Inventory_Content : Unbounded_String;
      begin
         Append
           (Inventory_Content,
            "executable,crate,package,manifest_path,project_file_path,documentation_path,"
            & "release_included,posix_status,help,version,identity"
            & Character'Val (10));

         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            Append
              (Inventory_Content,
               Posix_Tools.Command_Inventory.Executable (I)
               & "," & Posix_Tools.Command_Inventory.Crate (I)
               & "," & Posix_Tools.Command_Inventory.Package_Name (I)
               & "," & Posix_Tools.Command_Inventory.Manifest_Path (I)
               & "," & Posix_Tools.Command_Inventory.Project_File_Path (I)
               & "," & Posix_Tools.Command_Inventory.Documentation_Path (I)
               & "," & Boolean_Text (Posix_Tools.Command_Inventory.Release_Included (I))
               & "," & Posix_Tools.Command_Inventory.Posix_Status (I)
               & "," & Boolean_Text (Posix_Tools.Command_Inventory.Has_Help (I))
               & "," & Boolean_Text (Posix_Tools.Command_Inventory.Has_Version (I))
               & "," & Boolean_Text (Posix_Tools.Command_Inventory.Has_Identity (I))
               & Character'Val (10));
         end loop;

         return To_String (Inventory_Content);
      end Render_Command_Inventory;

      function Render_Command_Reference_Index return String is
         Index_Content : Unbounded_String;
         Root_Inserted : Boolean := False;
      begin
         Append (Index_Content, "# Command References" & Character'Val (10) & Character'Val (10));
         Append (Index_Content, "V1 command references:" & Character'Val (10) & Character'Val (10));

         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            if not Root_Inserted
              and then "posix-tools" < Posix_Tools.Command_Inventory.Executable (I)
            then
               Append (Index_Content, "- [posix-tools](posix-tools.md)" & Character'Val (10));
               Root_Inserted := True;
            end if;

            Append
              (Index_Content,
               "- [" & Posix_Tools.Command_Inventory.Executable (I) & "]("
               & Posix_Tools.Command_Inventory.Executable (I) & ".md)"
               & Character'Val (10));
         end loop;

         if not Root_Inserted then
            Append (Index_Content, "- [posix-tools](posix-tools.md)" & Character'Val (10));
         end if;

         return To_String (Index_Content);
      end Render_Command_Reference_Index;

      procedure Generate_Command_Inventory is
      begin
         Project_Tools.Files.Write_Raw_File
           (Project_Tools.Files.Join (Base, "generated/command_inventory.csv"),
            Render_Command_Inventory);
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
      Append (Content, "# Generated Manual Index" & Character'Val (10) & Character'Val (10));
      Append
        (Content,
         "Version: " & Posix_Tools.Version.Version_String
         & Character'Val (10) & Character'Val (10));

      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Generate_Manpage (I);
         Append
           (Content,
            "- `" & Posix_Tools.Command_Inventory.Executable (I) & "`: "
            & Posix_Tools.Command_Inventory.Documentation_Path (I)
            & Character'Val (10));
      end loop;
      Append (Content, Character'Val (10));

      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Base, "generated/manual-index.md"), To_String (Content));
      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Base, "docs/commands/index.md"), Render_Command_Reference_Index);
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
         Project_Tools.Release_Checks.Fail ("7z-compatible command not found for release archive generation");
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
         Project_Tools.Release_Checks.Fail
           ("release archive generation failed with status" & Integer'Image (Status));
      elsif not Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Archive)) then
         Project_Tools.Release_Checks.Fail ("release archive was not created");
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
         Project_Tools.Release_Checks.Fail
           ("release archive integrity test failed with status" & Integer'Image (Status));
      end if;

      Ada.Text_IO.Put_Line (Archive);
   end Generate_Release_Archive;

   function Built_Command_Path (Executable : String) return String;

   function Built_Root_Path return String;

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

   procedure Run_Conformance_Checks is
      use Ada.Strings.Unbounded;
      Check : constant Project_Tools.Release_Checks.Checker :=
        Project_Tools.Release_Checks.Create (Root);
      Requirements : constant String :=
        Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "generated/requirements.csv"));
      Regressions : constant String :=
        Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "generated/regressions.csv"));
      Inventory_Csv : constant String :=
        Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "generated/command_inventory.csv"));

      type Requirement_Row is record
         Id : Unbounded_String;
         Command : Unbounded_String;
         Posix_Reference : Unbounded_String;
         Implementation : Unbounded_String;
         Test : Unbounded_String;
         Status : Unbounded_String;
      end record;

      function Field (Line : String; Index : Positive) return String is
         Start : Positive := Line'First;
         Current : Positive := 1;
      begin
         for I in Line'Range loop
            if Line (I) = ',' then
               if Current = Index then
                  return Line (Start .. I - 1);
               end if;

               Current := Current + 1;
               Start := I + 1;
            end if;
         end loop;

         if Current = Index then
            return Line (Start .. Line'Last);
         end if;

         return "";
      end Field;

      function Field_Count (Line : String) return Natural is
         Count : Natural := 1;
      begin
         if Line = "" then
            return 0;
         end if;

         for Ch of Line loop
            if Ch = ',' then
               Count := Count + 1;
            end if;
         end loop;

         return Count;
      end Field_Count;

      function Is_Allowed_Status (Status : String) return Boolean is
      begin
         return Status = "Conforming"
           or else Status = "Conforming with implementation-defined behavior"
           or else Status = "Conforming with extensions"
           or else Status = "Partially conforming"
           or else Status = "Not yet assessed"
           or else Status = "Known deviation";
      end Is_Allowed_Status;

      function Is_Requirement_Id (Text : String) return Boolean is
         Has_Hyphen : Boolean := False;
      begin
         if Text = "" or else Text (Text'First) = '-' or else Text (Text'Last) = '-' then
            return False;
         end if;

         for Ch of Text loop
            if Ch = '-' then
               Has_Hyphen := True;
            elsif not
              (Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper (Ch)
               or else Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Ch))
            then
               return False;
            end if;
         end loop;

         return Has_Hyphen;
      end Is_Requirement_Id;

      function Is_Regression_Id (Text : String) return Boolean is
         Prefix : constant String := "REG-";
         Last_Hyphen : Natural := 0;
      begin
         if Text'Length < Prefix'Length + 6
           or else not Posix_Tools.Text.Matching.Starts_With (Text, Prefix)
         then
            return False;
         end if;

         for I in Text'First + Prefix'Length .. Text'Last loop
            if Text (I) = '-' then
               Last_Hyphen := I;
            elsif not
              (Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper (Text (I))
               or else Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I)))
            then
               return False;
            end if;
         end loop;

         if Last_Hyphen = 0
           or else Text'Last - Last_Hyphen /= 4
         then
            return False;
         end if;

         for I in Last_Hyphen + 1 .. Text'Last loop
            if not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I)) then
               return False;
            end if;
         end loop;

         return True;
      end Is_Regression_Id;

      function Trimmed (Text : String) return String is
      begin
         return Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      end Trimmed;

      function Unit_File_Stem (Unit_Name : String) return String is
         Stem : String := Ada.Characters.Handling.To_Lower (Unit_Name);
      begin
         for Ch of Stem loop
            if Ch = '.' then
               Ch := '-';
            end if;
         end loop;

         return Stem;
      end Unit_File_Stem;

      function Is_Source_Unit_Reference (Reference : String) return Boolean is
         Posix_Prefix : constant String := "Posix_Tools.";
         Tools_Prefix : constant String := "Project_Tools.";
      begin
         return ((Reference'Length > Posix_Prefix'Length
                  and then Reference (Reference'First .. Reference'First + Posix_Prefix'Length - 1) = Posix_Prefix)
                 or else (Reference'Length > Tools_Prefix'Length
                          and then Reference (Reference'First .. Reference'First + Tools_Prefix'Length - 1) =
                            Tools_Prefix))
           and then not Project_Tools.Text.Contains (Reference, "/")
           and then not Project_Tools.Text.Contains (Reference, "*");
      end Is_Source_Unit_Reference;

      function Is_Bare_File_Name (Reference : String) return Boolean is
      begin
         return not Project_Tools.Text.Contains (Reference, "/")
           and then not Project_Tools.Text.Contains (Reference, "\")
           and then not Project_Tools.Text.Contains (Reference, "*");
      end Is_Bare_File_Name;

      function Referenced_Source_Exists (Reference : String) return Boolean is
         Stem : constant String := Unit_File_Stem (Reference);
      begin
         return Project_Tools.Files.File_Exists
             (Project_Tools.Files.Join (Root, "common/src/" & Stem & ".ads"))
           or else Project_Tools.Files.File_Exists
             (Project_Tools.Files.Join (Root, "common/src/" & Stem & ".adb"))
           or else Project_Tools.Files.File_Exists
             (Project_Tools.Files.Join (Root, "common/generated/" & Stem & ".ads"))
           or else Project_Tools.Files.File_Exists
             (Project_Tools.Files.Join (Root, "common/generated/" & Stem & ".adb"))
           or else Project_Tools.Files.File_Exists
             (Project_Tools.Files.Join (Root, "tests/src/" & Stem & ".ads"))
           or else Project_Tools.Files.File_Exists
             (Project_Tools.Files.Join (Root, "tests/src/" & Stem & ".adb"))
           or else Project_Tools.Files.File_Exists
             (Project_Tools.Files.Join (Root, Stem & ".gpr"));
      end Referenced_Source_Exists;

      function Referenced_Path_Exists (Reference : String) return Boolean is
      begin
         if Reference = "generated/man/*.1" then
            return Project_Tools.Files.File_Exists
                (Project_Tools.Files.Join (Root, "generated/man/basename.1"));
         elsif Reference = "tools/*/src/*.adb" then
            return Project_Tools.Files.File_Exists
                (Project_Tools.Files.Join (Root, "tools/basename/src/basename.adb"));
         elsif Reference = "tools/*/alire.toml" then
            return Project_Tools.Files.File_Exists
                (Project_Tools.Files.Join (Root, "tools/basename/alire.toml"));
         elsif Reference = "docs/commands/*.md" then
            return Project_Tools.Files.File_Exists
                (Project_Tools.Files.Join (Root, "docs/commands/basename.md"));
         else
            return Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Reference))
              or else Project_Tools.Files.Directory_Exists (Project_Tools.Files.Join (Root, Reference))
              or else (Is_Bare_File_Name (Reference)
                       and then Project_Tools.Files.Find_File (Root, Reference) /= "");
         end if;
      end Referenced_Path_Exists;

      function Implementation_Reference_Exists (Reference : String) return Boolean is
         Item : constant String := Trimmed (Reference);
      begin
         if Item = "" then
            return False;
         elsif Is_Source_Unit_Reference (Item) then
            return Referenced_Source_Exists (Item);
         else
            return Referenced_Path_Exists (Item);
         end if;
      end Implementation_Reference_Exists;

      function Has_AUnit_Test (Name : String) return Boolean is
         Needle : constant String := """" & Name & """";
      begin
         return Project_Tools.Files.File_Contains
             (Project_Tools.Files.Join (Root, "tests/src/basic_tests-suite.adb"), Needle)
           or else Project_Tools.Files.File_Contains
             (Project_Tools.Files.Join (Root, "tests/src/command_tests-suite_entries.adb"), Needle);
      end Has_AUnit_Test;

      function Has_Regression_Id (Name : String) return Boolean is
      begin
         return Project_Tools.Files.File_Contains
           (Project_Tools.Files.Join (Root, "generated/regressions.csv"), Name & ",");
      end Has_Regression_Id;

      function Requirement_References_Regression (Name : String) return Boolean is
      begin
         return Project_Tools.Text.Contains (Requirements, "regression " & Name);
      end Requirement_References_Regression;

      function Is_Project_Tooling_Test (Reference : String) return Boolean is
      begin
         return Reference = "posix_tools_tests build"
           or else Reference = "posix_tools_tests check"
           or else Reference = "posix_tools_tests conformance"
           or else Reference = "posix_tools_tests docs"
           or else Reference = "posix_tools_tests format-check"
           or else Reference = "posix_tools_tests package"
           or else Reference = "posix_tools_tests prove"
           or else Reference = "posix_tools_tests release"
           or else Reference = "posix_tools_tests release-check"
           or else Reference = "posix_tools_tests test --category conformance"
           or else Reference = "posix_tools_tests test --category integration"
           or else Reference = "posix_tools_tests test --category locale"
           or else Reference = "posix_tools_tests test --category presentation"
           or else Reference = "posix_tools_tests test --category regression"
           or else Reference = "posix_tools_tests test --category unit"
           or else Reference = "posix_tools_tests test --suite cat"
           or else Reference = "posix_tools_tests test --suite command"
           or else Reference = "posix_tools_tests test --suite cp"
           or else Reference = "posix_tools_tests test --suite root"
           or else Reference = "posix_tools_tests test --suite xargs"
           or else Reference = "CI release check"
           or else Reference = "posix-tools verify smoke";
      end Is_Project_Tooling_Test;

      function Test_Reference_Exists (Reference : String) return Boolean is
         Item : constant String := Trimmed (Reference);
         Regression_Prefix : constant String := "regression ";
      begin
         if Item = "" then
            return False;
         elsif Item'Length > Regression_Prefix'Length
           and then Item (Item'First .. Item'First + Regression_Prefix'Length - 1) = Regression_Prefix
         then
            return Has_Regression_Id (Item (Item'First + Regression_Prefix'Length .. Item'Last));
         elsif Project_Tools.Text.Contains (Item, "/") then
            return Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Item));
         else
            return Has_AUnit_Test (Item) or else Is_Project_Tooling_Test (Item);
         end if;
      end Test_Reference_Exists;

      procedure Check_Implementation_References (Id_Text : String; Text : String) is
         Start : Positive := Text'First;
      begin
         if Text = "" then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " has no implementation references");
         end if;

         for I in Text'Range loop
            if Text (I) = ';' then
               if Start <= I - 1
                 and then not Implementation_Reference_Exists (Text (Start .. I - 1))
               then
                  Project_Tools.Release_Checks.Fail
                    (Id_Text & " references missing implementation " & Trimmed (Text (Start .. I - 1)));
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Text'Last
           and then not Implementation_Reference_Exists (Text (Start .. Text'Last))
         then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " references missing implementation " & Trimmed (Text (Start .. Text'Last)));
         end if;
      end Check_Implementation_References;

      procedure Check_Test_References (Id_Text : String; Text : String) is
         Start : Positive := Text'First;
      begin
         if Text = "" then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " has no test references");
         end if;

         for I in Text'Range loop
            if Text (I) = ';' then
               if Start <= I - 1
                 and then not Test_Reference_Exists (Text (Start .. I - 1))
               then
                  Project_Tools.Release_Checks.Fail
                    (Id_Text & " references missing test or validation artifact "
                     & Trimmed (Text (Start .. I - 1)));
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Text'Last
           and then not Test_Reference_Exists (Text (Start .. Text'Last))
         then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " references missing test or validation artifact "
               & Trimmed (Text (Start .. Text'Last)));
         end if;
      end Check_Test_References;

      procedure Check_Regression_Row (Line : String; Number : Positive) is
         Id_Text : constant String := Field (Line, 1);
         Test_Text : constant String := Field (Line, 4);
      begin
         if Field_Count (Line) /= 4 then
            Project_Tools.Release_Checks.Fail
              ("regression row has wrong field count at line" & Positive'Image (Number));
         elsif Id_Text = "" then
            Project_Tools.Release_Checks.Fail
              ("regression row has empty identifier at line" & Positive'Image (Number));
         elsif not Is_Regression_Id (Id_Text) then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " has invalid regression identifier syntax");
         elsif Field (Line, 2) = "" then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " has empty command field");
         elsif Field (Line, 3) = "" then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " has empty summary field");
         elsif Test_Text = "" then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " has no linked regression test");
         elsif not Requirement_References_Regression (Id_Text) then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " is not referenced by any requirement row");
         else
            Check_Test_References (Id_Text, Test_Text);
         end if;
      end Check_Regression_Row;

      function Inventory_Boolean_Text (Value : Boolean) return String is
      begin
         if Value then
            return "true";
         else
            return "false";
         end if;
      end Inventory_Boolean_Text;

      procedure Check_Inventory_Path (Executable : String; Path : String; Label : String) is
      begin
         if Path = "" then
            Project_Tools.Release_Checks.Fail
              ("inventory row for " & Executable & " has empty " & Label);
         elsif not Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Path)) then
            Project_Tools.Release_Checks.Fail
              ("inventory row for " & Executable & " references missing " & Label & " " & Path);
         end if;
      end Check_Inventory_Path;

      procedure Require_Inventory_Field
        (Executable : String;
         Label      : String;
         Actual     : String;
         Expected   : String) is
      begin
         if Actual /= Expected then
            Project_Tools.Release_Checks.Fail
              ("inventory row for " & Executable & " has " & Label & " '" & Actual
               & "' but expected '" & Expected & "'");
         end if;
      end Require_Inventory_Field;

      procedure Check_Inventory_Row (Line : String; Number : Positive) is
         Index : constant Positive := Number - 1;
         Executable : constant String := Field (Line, 1);
      begin
         if Field_Count (Line) /= 11 then
            Project_Tools.Release_Checks.Fail
              ("command inventory row has wrong field count at line" & Positive'Image (Number));
         elsif Index > Posix_Tools.Command_Inventory.Command_Count then
            Project_Tools.Release_Checks.Fail
              ("command inventory has unexpected extra row at line" & Positive'Image (Number));
         end if;

         Require_Inventory_Field
           (Executable, "executable", Executable, Posix_Tools.Command_Inventory.Executable (Index));
         Require_Inventory_Field
           (Executable, "crate", Field (Line, 2), Posix_Tools.Command_Inventory.Crate (Index));
         Require_Inventory_Field
           (Executable, "package", Field (Line, 3), Posix_Tools.Command_Inventory.Package_Name (Index));
         Require_Inventory_Field
           (Executable, "manifest path", Field (Line, 4), Posix_Tools.Command_Inventory.Manifest_Path (Index));
         Require_Inventory_Field
           (Executable,
            "project file path",
            Field (Line, 5),
            Posix_Tools.Command_Inventory.Project_File_Path (Index));
         Require_Inventory_Field
           (Executable,
            "documentation path",
            Field (Line, 6),
            Posix_Tools.Command_Inventory.Documentation_Path (Index));
         Require_Inventory_Field
           (Executable,
            "release flag",
            Field (Line, 7),
            Inventory_Boolean_Text (Posix_Tools.Command_Inventory.Release_Included (Index)));
         Require_Inventory_Field
           (Executable, "POSIX status", Field (Line, 8), Posix_Tools.Command_Inventory.Posix_Status (Index));
         Require_Inventory_Field
           (Executable,
            "help flag",
            Field (Line, 9),
            Inventory_Boolean_Text (Posix_Tools.Command_Inventory.Has_Help (Index)));
         Require_Inventory_Field
           (Executable,
            "version flag",
            Field (Line, 10),
            Inventory_Boolean_Text (Posix_Tools.Command_Inventory.Has_Version (Index)));
         Require_Inventory_Field
           (Executable,
            "identity flag",
            Field (Line, 11),
            Inventory_Boolean_Text (Posix_Tools.Command_Inventory.Has_Identity (Index)));

         Check_Inventory_Path (Executable, Field (Line, 4), "manifest path");
         Check_Inventory_Path (Executable, Field (Line, 5), "project file path");
         Check_Inventory_Path (Executable, Field (Line, 6), "documentation path");
         Check_Inventory_Path
           (Executable, Posix_Tools.Command_Inventory.Wrapper_Path (Index), "wrapper source path");
      end Check_Inventory_Row;

      function Contains_Token (Text : String; Token : String) return Boolean is
         Start : Positive := Text'First;
      begin
         if Text = "" then
            return False;
         end if;

         for I in Text'Range loop
            if Text (I) = ' ' then
               if Start <= I - 1 and then Text (Start .. I - 1) = Token then
                  return True;
               end if;

               Start := I + 1;
            end if;
         end loop;

         return Start <= Text'Last and then Text (Start .. Text'Last) = Token;
      end Contains_Token;

      function First_Doc_Path (Text : String) return String is
      begin
         for I in Text'Range loop
            if Posix_Tools.Text.Matching.Starts_With_At (Text, "docs/", I) then
               for J in I .. Text'Last loop
                  if Text (J) = ';' or else Text (J) = ' ' then
                     return Text (I .. J - 1);
                  end if;
               end loop;

               return Text (I .. Text'Last);
            end if;
         end loop;

         return "";
      end First_Doc_Path;

      function Has_Command_Metadata (Executable : String) return Boolean is
         Start : Positive := Requirements'First;
      begin
         for I in Requirements'Range loop
            if Requirements (I) = Character'Val (10) then
               if I > Start then
                  declare
                     Line : constant String :=
                       Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                         (Requirements (Start .. I - 1));
                  begin
                     if Field (Line, 1) /= "id"
                       and then Contains_Token (Field (Line, 2), Executable)
                     then
                        return True;
                     end if;
                  end;
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Requirements'Last then
            declare
               Line : constant String :=
                 Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                   (Requirements (Start .. Requirements'Last));
            begin
               return Field (Line, 1) /= "id"
                 and then Contains_Token (Field (Line, 2), Executable);
            end;
         end if;

         return False;
      end Has_Command_Metadata;

      function Has_Known_Deviation_Metadata (Executable : String) return Boolean is
         Start : Positive := Requirements'First;
      begin
         for I in Requirements'Range loop
            if Requirements (I) = Character'Val (10) then
               if I > Start then
                  declare
                     Line : constant String :=
                       Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                         (Requirements (Start .. I - 1));
                  begin
                     if Field (Line, 1) /= "id"
                       and then Contains_Token (Field (Line, 2), Executable)
                       and then Field (Line, 7) = "Known deviation"
                     then
                        return True;
                     end if;
                  end;
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Requirements'Last then
            declare
               Line : constant String :=
                 Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                   (Requirements (Start .. Requirements'Last));
            begin
               return Field (Line, 1) /= "id"
                 and then Contains_Token (Field (Line, 2), Executable)
                 and then Field (Line, 7) = "Known deviation";
            end;
         end if;

         return False;
      end Has_Known_Deviation_Metadata;

      procedure Check_Row (Line : String; Number : Positive) is
         Row : constant Requirement_Row :=
           (Id              => To_Unbounded_String (Field (Line, 1)),
            Command         => To_Unbounded_String (Field (Line, 2)),
            Posix_Reference => To_Unbounded_String (Field (Line, 4)),
            Implementation  => To_Unbounded_String (Field (Line, 5)),
            Test            => To_Unbounded_String (Field (Line, 6)),
            Status          => To_Unbounded_String (Field (Line, 7)));
         Id_Text : constant String := To_String (Row.Id);
         Status_Text : constant String := To_String (Row.Status);
         Test_Text : constant String := To_String (Row.Test);
         Implementation_Text : constant String := To_String (Row.Implementation);
      begin
         if Field_Count (Line) /= 7 then
            Project_Tools.Release_Checks.Fail
              ("requirement row has wrong field count at line" & Positive'Image (Number));
         elsif Id_Text = "" then
            Project_Tools.Release_Checks.Fail
              ("requirement row has empty identifier at line" & Positive'Image (Number));
         elsif not Is_Requirement_Id (Id_Text) then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " has invalid requirement identifier syntax");
         elsif To_String (Row.Command) = "" then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " has empty command field");
         elsif To_String (Row.Implementation) = "" then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " has empty implementation field");
         elsif To_String (Row.Test) = "" then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " has no linked test or validation artifact");
         elsif not Is_Allowed_Status (Status_Text) then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " has invalid conformance status " & Status_Text);
         elsif Project_Tools.Text.Contains (To_String (Row.Posix_Reference), "POSIX.1-2008")
           or else Project_Tools.Text.Contains (To_String (Row.Posix_Reference), "POSIX.1-2017")
           or else Project_Tools.Text.Contains (To_String (Row.Posix_Reference), "Issue 7")
         then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " mixes an older POSIX baseline into the V1 registry");
         elsif To_String (Row.Posix_Reference) = "Project extension"
           and then not
             (Project_Tools.Text.Contains (Id_Text, "-EXT-")
              or else Posix_Tools.Text.Matching.Starts_With (Id_Text, "NONPOSIX-"))
         then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " records a project extension without an extension identifier");
         else
            Check_Implementation_References (Id_Text, Implementation_Text);
            Check_Test_References (Id_Text, Test_Text);
         end if;

         if Status_Text = "Known deviation"
           and then not Project_Tools.Text.Contains (Test_Text, "docs/")
         then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " is a known deviation without linked documentation");
         elsif Status_Text = "Known deviation"
         then
            declare
               Doc_Path : constant String := First_Doc_Path (Test_Text);
            begin
               if Doc_Path = ""
                 or else not Project_Tools.Files.File_Contains
                   (Project_Tools.Files.Join (Root, Doc_Path), Id_Text)
               then
                  Project_Tools.Release_Checks.Fail
                    (Id_Text & " is a known deviation missing its identifier in linked documentation");
               end if;
            end;
         end if;
      end Check_Row;

      procedure Check_Requirement_Rows is
         Start : Positive := Requirements'First;
         Line_Number : Positive := 1;
         Max_Requirement_Rows : constant Positive := 512;
         type Seen_Id_Array is array (Positive range <>) of Unbounded_String;
         Seen_Ids : Seen_Id_Array (1 .. Max_Requirement_Rows);
         Seen_Count : Natural := 0;

         procedure Remember_Id (Line : String; Number : Positive) is
            Id_Text : constant String := Field (Line, 1);
         begin
            for I in 1 .. Seen_Count loop
               if To_String (Seen_Ids (I)) = Id_Text then
                  Project_Tools.Release_Checks.Fail
                    ("duplicate requirement identifier " & Id_Text
                     & " at line" & Positive'Image (Number));
               end if;
            end loop;

            if Seen_Count = Max_Requirement_Rows then
               Project_Tools.Release_Checks.Fail ("requirements registry exceeds tooling row capacity");
            end if;

            Seen_Count := Seen_Count + 1;
            Seen_Ids (Seen_Count) := To_Unbounded_String (Id_Text);
         end Remember_Id;
      begin
         if Requirements = "" then
            Project_Tools.Release_Checks.Fail ("requirements registry is empty");
         end if;

         for I in Requirements'Range loop
            if Requirements (I) = Character'Val (10) then
               if I > Start then
                  declare
                     Line : constant String :=
                       Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                         (Requirements (Start .. I - 1));
                  begin
                     if Line_Number = 1 then
                        if Line /= "id,command,summary,posix_reference,implementation,test,status" then
                           Project_Tools.Release_Checks.Fail ("requirements registry header is invalid");
                        end if;
                     else
                        Check_Row (Line, Line_Number);
                        Remember_Id (Line, Line_Number);
                     end if;
                  end;
               end if;

               Line_Number := Line_Number + 1;
               Start := I + 1;
            end if;
         end loop;

         if Start <= Requirements'Last then
            declare
               Line : constant String :=
                 Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                   (Requirements (Start .. Requirements'Last));
            begin
               Check_Row (Line, Line_Number);
               Remember_Id (Line, Line_Number);
            end;
         end if;
      end Check_Requirement_Rows;

      procedure Check_Regression_Rows is
         Start : Positive := Regressions'First;
         Line_Number : Positive := 1;
         Max_Regression_Rows : constant Positive := 256;
         type Seen_Id_Array is array (Positive range <>) of Unbounded_String;
         Seen_Ids : Seen_Id_Array (1 .. Max_Regression_Rows);
         Seen_Count : Natural := 0;

         procedure Remember_Id (Line : String; Number : Positive) is
            Id_Text : constant String := Field (Line, 1);
         begin
            for I in 1 .. Seen_Count loop
               if To_String (Seen_Ids (I)) = Id_Text then
                  Project_Tools.Release_Checks.Fail
                    ("duplicate regression identifier " & Id_Text
                     & " at line" & Positive'Image (Number));
               end if;
            end loop;

            if Seen_Count = Max_Regression_Rows then
               Project_Tools.Release_Checks.Fail ("regression registry exceeds tooling row capacity");
            end if;

            Seen_Count := Seen_Count + 1;
            Seen_Ids (Seen_Count) := To_Unbounded_String (Id_Text);
         end Remember_Id;
      begin
         if Regressions = "" then
            Project_Tools.Release_Checks.Fail ("regression registry is empty");
         end if;

         for I in Regressions'Range loop
            if Regressions (I) = Character'Val (10) then
               if I > Start then
                  declare
                     Line : constant String :=
                       Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                         (Regressions (Start .. I - 1));
                  begin
                     if Line_Number = 1 then
                        if Line /= "id,command,summary,test" then
                           Project_Tools.Release_Checks.Fail ("regression registry header is invalid");
                        end if;
                     else
                        Check_Regression_Row (Line, Line_Number);
                        Remember_Id (Line, Line_Number);
                     end if;
                  end;
               end if;

               Line_Number := Line_Number + 1;
               Start := I + 1;
            end if;
         end loop;

         if Start <= Regressions'Last then
            declare
               Line : constant String :=
                 Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                   (Regressions (Start .. Regressions'Last));
            begin
               Check_Regression_Row (Line, Line_Number);
               Remember_Id (Line, Line_Number);
            end;
         end if;
      end Check_Regression_Rows;

      procedure Check_Inventory_Rows is
         Start : Positive := Inventory_Csv'First;
         Line_Number : Positive := 1;
         Row_Count : Natural := 0;
      begin
         if Inventory_Csv = "" then
            Project_Tools.Release_Checks.Fail ("command inventory is empty");
         end if;

         for I in Inventory_Csv'Range loop
            if Inventory_Csv (I) = Character'Val (10) then
               if I > Start then
                  declare
                     Line : constant String :=
                       Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                         (Inventory_Csv (Start .. I - 1));
                  begin
                     if Line_Number = 1 then
                        if Line /=
                          "executable,crate,package,manifest_path,project_file_path,documentation_path,"
                          & "release_included,posix_status,help,version,identity"
                        then
                           Project_Tools.Release_Checks.Fail ("command inventory header is invalid");
                        end if;
                     else
                        Check_Inventory_Row (Line, Line_Number);
                        Row_Count := Row_Count + 1;
                     end if;
                  end;
               end if;

               Line_Number := Line_Number + 1;
               Start := I + 1;
            end if;
         end loop;

         if Start <= Inventory_Csv'Last then
            declare
               Line : constant String :=
                 Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                   (Inventory_Csv (Start .. Inventory_Csv'Last));
            begin
               Check_Inventory_Row (Line, Line_Number);
               Row_Count := Row_Count + 1;
            end;
         end if;

         if Row_Count /= Posix_Tools.Command_Inventory.Command_Count then
            Project_Tools.Release_Checks.Fail
              ("command inventory row count does not match compiled inventory");
         end if;
      end Check_Inventory_Rows;
   begin
      Check_Requirement_Rows;
      Check_Regression_Rows;
      Check_Inventory_Rows;
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         if not Has_Command_Metadata (Posix_Tools.Command_Inventory.Executable (I)) then
            Project_Tools.Release_Checks.Fail
              ("released command lacks conformance metadata: "
               & Posix_Tools.Command_Inventory.Executable (I));
         end if;

         if Posix_Tools.Command_Inventory.Posix_Status (I) = "known_deviation" then
            if not Has_Known_Deviation_Metadata (Posix_Tools.Command_Inventory.Executable (I)) then
               Project_Tools.Release_Checks.Fail
                 ("inventory command is marked known_deviation without matching requirement row: "
                  & Posix_Tools.Command_Inventory.Executable (I));
            end if;
         elsif Has_Known_Deviation_Metadata (Posix_Tools.Command_Inventory.Executable (I)) then
            Project_Tools.Release_Checks.Fail
              ("requirement registry has a known deviation for inventory command not marked known_deviation: "
               & Posix_Tools.Command_Inventory.Executable (I));
         end if;
      end loop;
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "Conforming with extensions");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/conformance.md", "POSIX.1-2024");
      Ada.Text_IO.Put_Line ("conformance metadata checks passed");
   end Run_Conformance_Checks;

   procedure Run_Format_Checks is
   begin
      Format_Checks.Run (Root);
   end Run_Format_Checks;

   procedure Run_Build is
   begin
      Build_Checks.Run (Root);
   end Run_Build;

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
         Project_Tools.Release_Checks.Fail
           ("proof target " & Unit_Name & " failed in " & Mode & " mode");
      end if;
   end Prove_Target;

   procedure Run_Proof_Checks is
      procedure Run_Targets is new Proof_Targets (Prove_Target);
      Gnatprove : constant String := Project_Tools.Processes.Locate_Command ("gnatprove");
   begin
      if Gnatprove = "" then
         Project_Tools.Release_Checks.Fail
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
         Project_Tools.Release_Checks.Fail ("git command not found for release clean-tree check");
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
         Project_Tools.Release_Checks.Fail ("git status failed during release clean-tree check");
      elsif To_String (Result.Output) /= "" then
         Project_Tools.Release_Checks.Fail ("release requires a clean source tree");
      end if;
   end Require_Clean_Source_Tree;

   function Built_Command_Path (Executable : String) return String is
      Base_Path : constant String :=
        Project_Tools.Files.Join (Root, "tools/" & Executable & "/bin/" & Executable);
   begin
      if Project_Tools.Files.File_Exists (Base_Path) then
         return Ada.Directories.Full_Name (Base_Path);
      elsif Project_Tools.Files.File_Exists (Base_Path & ".exe") then
         return Ada.Directories.Full_Name (Base_Path & ".exe");
      else
         return Base_Path;
      end if;
   end Built_Command_Path;

   function Built_Root_Path return String is
      Base_Path : constant String := Project_Tools.Files.Join (Root, "bin/posix-tools");
   begin
      if Project_Tools.Files.File_Exists (Base_Path) then
         return Ada.Directories.Full_Name (Base_Path);
      elsif Project_Tools.Files.File_Exists (Base_Path & ".exe") then
         return Ada.Directories.Full_Name (Base_Path & ".exe");
      else
         return Base_Path;
      end if;
   end Built_Root_Path;

   function Built_Test_Runner_Path return String is
      Base_Path : constant String := Project_Tools.Files.Join (Root, "tests/bin/posix_tools_tests");
   begin
      if Project_Tools.Files.File_Exists (Base_Path) then
         return Ada.Directories.Full_Name (Base_Path);
      elsif Project_Tools.Files.File_Exists (Base_Path & ".exe") then
         return Ada.Directories.Full_Name (Base_Path & ".exe");
      else
         return Base_Path;
      end if;
   end Built_Test_Runner_Path;

   procedure Run_Test_Selector_Smoke is
      use Ada.Strings.Unbounded;

      Runner_Path : constant String := Built_Test_Runner_Path;

      procedure Expect_Selector
        (Label  : String;
         Args   : Project_Tools.Processes.Argument_Vectors.Vector;
         Needle : String)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture
             (Label   => Label,
              Dir     => Root,
              Program => Runner_Path,
              Args    => Args,
              Quiet   => True);
      begin
         if Captured.Status /= 0 then
            --  The suite's own report says which test failed and why.
            Ada.Text_IO.Put_Line (To_String (Captured.Output));
            Project_Tools.Release_Checks.Fail
              (Label & " failed with status" & Integer'Image (Captured.Status));
         elsif not Project_Tools.Text.Contains (To_String (Captured.Output), Needle) then
            Project_Tools.Release_Checks.Fail
              (Label & " output did not include " & Needle);
         end if;
      end Expect_Selector;

      procedure Expect_Usage_Error
        (Label : String;
         Args  : Project_Tools.Processes.Argument_Vectors.Vector)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture_Command
             (Command    => Runner_Path,
              Arguments  => Args,
              Err_To_Out => True);
      begin
         if Captured.Status /= 2 then
            Project_Tools.Release_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status)
               & " instead of usage status 2");
         end if;
      end Expect_Usage_Error;
   begin
      if not Project_Tools.Files.File_Exists (Runner_Path) then
         Project_Tools.Release_Checks.Fail ("built test runner is missing for selector smoke tests");
      end if;

      Expect_Selector
        ("test selector suite cat",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("cat")]),
         "command:cat");
      Expect_Selector
        ("test selector suite cp",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("cp")]),
         "command:cp");
      Expect_Selector
        ("test selector suite xargs",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("xargs")]),
         "command:xargs");
      Expect_Selector
        ("test selector suite root",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("root")]),
         "command:root");
      Expect_Selector
        ("test selector suite command",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("command")]),
         "command:basename");
      Expect_Selector
        ("test selector category unit",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("unit")]),
         "basic:numbers");
      Expect_Selector
        ("test selector category integration",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("integration")]),
         "command:root");
      Expect_Selector
        ("test selector category conformance",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("conformance")]),
         "basic:command inventory");
      Expect_Selector
        ("test selector category regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-CAT-0001");
      Expect_Selector
        ("test selector command regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-STDOUT-0004");
      Expect_Selector
        ("test selector env regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-ENV-0001");
      Expect_Selector
        ("test selector verbose regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-VERBOSE-0001");
      Expect_Selector
        ("test selector xargs regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-XARGS-0001");
      Expect_Selector
        ("test selector category locale",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("locale")]),
         "locale:help");
      Expect_Selector
        ("test selector category presentation",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("presentation")]),
         "presentation:styling");
      Expect_Usage_Error
        ("test selector missing suite value",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite")]));
      Expect_Usage_Error
        ("test selector unknown suite",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("unknown")]));
      Expect_Usage_Error
        ("test selector unknown category",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("unknown")]));

      Ada.Text_IO.Put_Line ("test selector smoke checks passed");
   end Run_Test_Selector_Smoke;

   procedure Run_Staged_Verification is
      use Ada.Strings.Unbounded;

      function Display_Output (Text : String) return String is
         Result : Unbounded_String;
      begin
         for Ch of Text loop
            case Ch is
               when Character'Val (10) =>
                  Append (Result, "\n");
               when Character'Val (13) =>
                  Append (Result, "\r");
               when Character'Val (9) =>
                  Append (Result, "\t");
               when others =>
                  Append (Result, Ch);
            end case;
         end loop;

         return To_String (Result);
      end Display_Output;

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
      begin
         return
           " path=""" & Program & """"
           & " direct-status=" & Integer'Image (Captured.Status)
           & " direct-output=""" & Display_Output (To_String (Captured.Output)) & """";
      end Identity_Diagnostic;
   begin
      declare
         Program : constant String := Built_Root_Path;
         Status : constant String :=
           Posix_Tools.Host_Adapters.Executables.Verify_Identity_At_Path
             ("posix-tools", Program);
      begin
         if Status /= "ok" then
            Project_Tools.Release_Checks.Fail
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
            Project_Tools.Release_Checks.Fail
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
               Project_Tools.Release_Checks.Fail
                 ("staged verification failed for " & Executable & ": " & Status
                  & Identity_Diagnostic (Executable, Program));
            end if;
         end;
      end loop;

      Ada.Text_IO.Put_Line ("staged verification checks passed");
   end Run_Staged_Verification;

   procedure Run_Executable_Integration_Smoke is
      use Ada.Strings.Unbounded;

      function Display_Output (Text : String) return String is
         Result : Unbounded_String;
      begin
         for Ch of Text loop
            case Ch is
               when Character'Val (10) =>
                  Append (Result, "\n");
               when Character'Val (13) =>
                  Append (Result, "\r");
               when Character'Val (9) =>
                  Append (Result, "\t");
               when others =>
                  Append (Result, Ch);
            end case;
         end loop;

         return To_String (Result);
      end Display_Output;

      procedure Expect_Output
        (Label           : String;
         Program         : String;
         Args            : Project_Tools.Processes.Argument_Vectors.Vector;
         Expected_Status : Integer;
         Expected_Output : String)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture
             (Label   => Label,
              Dir     => Root,
              Program => Program,
              Args    => Args,
              Quiet   => True);
      begin
         if Captured.Status /= Expected_Status then
            --  Run it again with its errors kept: a crash says why on stderr.
            declare
               Again : constant Project_Tools.Processes.Captured_Process :=
                 Project_Tools.Processes.Capture_Command
                   (Command    => Program,
                    Arguments  => Args,
                    Err_To_Out => True);
            begin
               Ada.Text_IO.Put_Line (To_String (Again.Output));
            end;
            Project_Tools.Release_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status)
               & " instead of" & Integer'Image (Expected_Status));
         elsif To_String (Captured.Output) /= Expected_Output then
            Project_Tools.Release_Checks.Fail
              (Label & " produced unexpected output: expected """
               & Display_Output (Expected_Output) & """ actual """
               & Display_Output (To_String (Captured.Output)) & """");
         end if;
      end Expect_Output;

      procedure Expect_Nonempty_Line
        (Label   : String;
         Program : String;
         Args    : Project_Tools.Processes.Argument_Vectors.Vector)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture
             (Label   => Label,
              Dir     => Root,
              Program => Program,
              Args    => Args,
              Quiet   => True);
         Output : constant String := To_String (Captured.Output);
      begin
         if Captured.Status /= 0 then
            Project_Tools.Release_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status));
         elsif Output'Length <= 1 or else Output (Output'Last) /= Character'Val (10) then
            Project_Tools.Release_Checks.Fail (Label & " did not produce one nonempty line");
         end if;
      end Expect_Nonempty_Line;

      procedure Expect_Output_With_Input
        (Label           : String;
         Program         : String;
         Args            : Project_Tools.Processes.Argument_Vectors.Vector;
         Input           : String;
         Expected_Status : Integer;
         Expected_Output : String;
         Err_To_Out      : Boolean := False)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture_Command
             (Command   => Program,
              Arguments => Args,
              Input     => Input,
              Err_To_Out => Err_To_Out);
      begin
         if Captured.Status /= Expected_Status then
            Project_Tools.Release_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status)
               & " instead of" & Integer'Image (Expected_Status));
         elsif To_String (Captured.Output) /= Expected_Output then
            Project_Tools.Release_Checks.Fail
              (Label & " produced unexpected output: expected """
               & Display_Output (Expected_Output) & """ actual """
               & Display_Output (To_String (Captured.Output)) & """");
         end if;
      end Expect_Output_With_Input;

      LF : constant Character := Character'Val (10);

      function Identity_Output (Command : String) return String is
      begin
         return
           "schema=1" & LF
           & "project=posix-tools" & LF
           & "command=" & Command & LF
           & "version=" & Posix_Tools.Version.Version_String & LF;
      end Identity_Output;

      function Version_Output (Command : String) return String is
      begin
         if Command = "awk" then
            return
              "awk " & Posix_Tools.Version.Version_String & LF
              & "awklib 0.1.0" & LF
              & "license MIT" & LF;
         elsif Command = "grep" then
            return
              "grep " & Posix_Tools.Version.Version_String & LF
              & "engine greplib" & LF
              & "license MIT" & LF;
         elsif Command = "sed" then
            return
              "sed " & Posix_Tools.Version.Version_String & LF
              & "engine sedlib 0.1.0-dev" & LF
              & "license MIT" & LF;
         else
            return Command & " (posix-tools) " & Posix_Tools.Version.Version_String & LF;
         end if;
      end Version_Output;

      Smoke_File : constant String :=
        Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-smoke.txt");
      Smoke_Leaf : constant String := "posix-tools-executable-smoke.txt";

      procedure Expect_File (Label, Path, Expected_Content : String) is
      begin
         if not Project_Tools.Files.File_Exists (Path) then
            Project_Tools.Release_Checks.Fail (Label & " did not create expected file");
         else
            declare
               Actual_Content : constant String := Project_Tools.Files.Read_Raw_File (Path);
            begin
               if Actual_Content /= Expected_Content then
                  Project_Tools.Release_Checks.Fail
                    (Label & " created file with unexpected content: expected """
                     & Display_Output (Expected_Content) & """ actual """
                     & Display_Output (Actual_Content) & """");
               end if;
            end;
         end if;
      end Expect_File;

      procedure Remove_Path (Path : String) is
      begin
         if Project_Tools.Files.Directory_Exists (Path) then
            Project_Tools.Files.Delete_Tree (Path);
         else
            Project_Tools.Files.Delete_File_If_Present (Path);
         end if;
      end Remove_Path;
   begin
      Expect_Output
        ("root executable version",
         Built_Root_Path,
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--version")]),
         0,
         "posix-tools " & Posix_Tools.Version.Version_String & LF);

      Expect_Output
        ("root executable identity",
         Built_Root_Path,
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--posix-tools-identify")]),
         0,
         Identity_Output ("posix-tools"));

      Expect_Nonempty_Line
        ("root executable help",
         Built_Root_Path,
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--help")]));

      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Executable : constant String := Posix_Tools.Command_Inventory.Executable (I);
         begin
            Expect_Output
              (Executable & " executable version",
               Built_Command_Path (Executable),
               Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--version")]),
               0,
               Version_Output (Executable));

            Expect_Output
              (Executable & " executable identity",
               Built_Command_Path (Executable),
               Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--posix-tools-identify")]),
               0,
               Identity_Output (Executable));

            Expect_Nonempty_Line
              (Executable & " executable help",
               Built_Command_Path (Executable),
               Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--help")]));
         end;
      end loop;

      Project_Tools.Files.Write_Raw_File (Smoke_File, "alpha" & LF & "beta" & LF);

      Expect_Output
        ("basename executable data",
         Built_Command_Path ("basename"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         Smoke_Leaf & LF);

      Expect_Output
        ("cat executable data",
         Built_Command_Path ("cat"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF & "beta" & LF);

      Expect_Output
        ("dirname executable data",
         Built_Command_Path ("dirname"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         Posix_Tools.Paths.Dirname (Smoke_File) & LF);

      Expect_Output
        ("echo executable data",
         Built_Command_Path ("echo"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("alpha"),
             Project_Tools.Processes.Argument ("beta")]),
         0,
         "alpha beta" & LF);

      Expect_Output
        ("printf executable data",
         Built_Command_Path ("printf"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("%s:%s\n"),
             Project_Tools.Processes.Argument ("alpha"),
             Project_Tools.Processes.Argument ("beta")]),
         0,
         "alpha:beta" & LF);

      Expect_Output
        ("date executable data",
         Built_Command_Path ("date"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-u"),
                                             Project_Tools.Processes.Argument ("+%Z")]),
         0,
         "UTC" & LF);

      Expect_Output
        ("dd executable data",
         Built_Command_Path ("dd"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("if=" & Smoke_File),
                                             Project_Tools.Processes.Argument ("bs=5"),
                                             Project_Tools.Processes.Argument ("count=1")]),
         0,
         "alpha");

      Expect_Output
        ("env executable data",
         Built_Command_Path ("env"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-i"),
                                             Project_Tools.Processes.Argument ("NAME=value")]),
         0,
         "NAME=value" & LF);

      Expect_Output
        ("false executable status",
         Built_Command_Path ("false"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("ignored")]),
         1,
         "");

      Expect_Output
        ("head executable data",
         Built_Command_Path ("head"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("-n"),
             Project_Tools.Processes.Argument ("1"),
             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF);

      declare
         Copy_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-copy.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Copy_Target);
         Expect_Output
           ("cp executable data",
            Built_Command_Path ("cp"),
            Project_Tools.Processes.Arguments
              ([Project_Tools.Processes.Argument (Smoke_File),
                Project_Tools.Processes.Argument (Copy_Target)]),
            0,
            "");
         Expect_Output
           ("cp executable copied data",
            Built_Command_Path ("cat"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Copy_Target)]),
            0,
            "alpha" & LF & "beta" & LF);
         Project_Tools.Files.Delete_File_If_Present (Copy_Target);
      end;

      Expect_Output
        ("find executable data",
         Built_Command_Path ("find"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File),
                                             Project_Tools.Processes.Argument ("-type"),
                                             Project_Tools.Processes.Argument ("f")]),
         0,
         Smoke_File & LF);

      Expect_Output
        ("grep executable data",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("alpha"),
                                             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF);

      Expect_Output_With_Input
        ("grep executable basic regex default",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("a+b")]),
         "a+b" & LF & "ab" & LF,
         0,
         "a+b");

      Expect_Output_With_Input
        ("grep executable extended regex",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-E"),
                                             Project_Tools.Processes.Argument ("a+b")]),
         "a+b" & LF & "ab" & LF,
         0,
         "ab");

      Expect_Output_With_Input
        ("grep executable basic regex interval",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-G"),
                                             Project_Tools.Processes.Argument ("^a\{2,3\}$")]),
         "a" & LF & "aa" & LF & "aaa" & LF & "aaaa" & LF,
         0,
         "aa" & LF & "aaa");

      Expect_Output_With_Input
        ("grep executable basic regex grouping",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-G"),
                                             Project_Tools.Processes.Argument ("^a\(b\|c\)$")]),
         "ab" & LF & "ac" & LF & "ad" & LF,
         0,
         "ab" & LF & "ac");

      Expect_Output_With_Input
        ("grep executable basic regex equivalence class",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-G"),
                                             Project_Tools.Processes.Argument ("[[=a=]]")]),
         "=" & LF & "a" & LF & "b" & LF,
         0,
         "a");

      Expect_Output_With_Input
        ("grep executable basic regex collating symbol",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-G"),
                                             Project_Tools.Processes.Argument ("[[.ch.]]")]),
         "cat" & LF & "hat" & LF & "chord" & LF,
         0,
         "chord");

      declare
         Env_Command : constant String := Project_Tools.Processes.Locate_Command ("env");
         N_Tilde : constant String := Character'Val (16#C3#) & Character'Val (16#B1#);
      begin
         if Env_Command = "" then
            Project_Tools.Release_Checks.Fail ("grep locale range smoke requires env");
         end if;

         Expect_Output_With_Input
           ("grep executable basic regex locale range",
            Env_Command,
            Project_Tools.Processes.Arguments
              ([Project_Tools.Processes.Argument ("LC_ALL=es_ES.UTF-8"),
                Project_Tools.Processes.Argument (Built_Command_Path ("grep")),
                Project_Tools.Processes.Argument ("-G"),
                Project_Tools.Processes.Argument ("[n-o]")]),
            "n" & LF & N_Tilde & LF & "o" & LF & "p" & LF,
            0,
            "n" & LF & N_Tilde & LF & "o");
      end;

      Expect_Output
        ("grep executable context data",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-A"),
                                             Project_Tools.Processes.Argument ("1"),
                                             Project_Tools.Processes.Argument ("alpha"),
                                             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF & "beta" & LF);

      Expect_Output
        ("grep executable only-matching data",
         Built_Command_Path ("grep"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-ow"),
                                             Project_Tools.Processes.Argument ("alpha"),
                                             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF);

      declare
         Env_Command : constant String := Project_Tools.Processes.Locate_Command ("env");
      begin
         if Env_Command = "" then
            Project_Tools.Release_Checks.Fail ("grep localized diagnostic smoke requires env");
         end if;

         Expect_Output_With_Input
           ("grep executable localized diagnostic",
            Env_Command,
            Project_Tools.Processes.Arguments
              ([Project_Tools.Processes.Argument ("LC_ALL=da_DK.UTF-8"),
                Project_Tools.Processes.Argument (Built_Command_Path ("grep")),
                Project_Tools.Processes.Argument ("-Z"),
                Project_Tools.Processes.Argument ("pattern")]),
            "",
            2,
            "grep: ukendt valgmulighed '-Z'" & LF
            & "usage: grep [-EFGbciloLqRrvinHhwxs] [-A num] [-B num] [-C num] "
            & "[-m num] [-e pattern] [-f pattern_file] pattern [file...]",
            True);
      end;

      declare
         Grep_Dir : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-grep-dir");
         Grep_Subdir : constant String := Project_Tools.Files.Join (Grep_Dir, "sub");
         Grep_File : constant String := Project_Tools.Files.Join (Grep_Subdir, "hit.txt");
      begin
         Remove_Path (Grep_Dir);
         Expect_Output
           ("grep executable recursive mkdir root",
            Built_Command_Path ("mkdir"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Grep_Dir)]),
            0,
            "");
         Expect_Output
           ("grep executable recursive mkdir sub",
            Built_Command_Path ("mkdir"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Grep_Subdir)]),
            0,
            "");
         Project_Tools.Files.Write_Raw_File (Grep_File, "needle" & LF);
         Expect_Output
           ("grep executable recursive data",
            Built_Command_Path ("grep"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-r"),
                                                Project_Tools.Processes.Argument ("needle"),
                                                Project_Tools.Processes.Argument (Grep_Dir)]),
            0,
            Grep_File & ":needle" & LF);
         Remove_Path (Grep_Dir);
      end;

      declare
         Link_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-link.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Link_Target);
         Expect_Output
           ("ln executable data",
            Built_Command_Path ("ln"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File),
                                                Project_Tools.Processes.Argument (Link_Target)]),
            0,
            "");
         Expect_Output
           ("ln executable linked data",
            Built_Command_Path ("cat"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Link_Target)]),
            0,
            "alpha" & LF & "beta" & LF);
         Project_Tools.Files.Delete_File_If_Present (Link_Target);
      end;

      declare
         Made_Dir : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-mkdir");
      begin
         Remove_Path (Made_Dir);
         Expect_Output
           ("mkdir executable data",
            Built_Command_Path ("mkdir"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Made_Dir)]),
            0,
            "");
         if not Project_Tools.Files.Directory_Exists (Made_Dir) then
            Project_Tools.Release_Checks.Fail ("mkdir executable data did not create directory");
         end if;
         Expect_Output
           ("rmdir executable data",
            Built_Command_Path ("rmdir"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Made_Dir)]),
            0,
            "");
         if Project_Tools.Files.Directory_Exists (Made_Dir) then
            Project_Tools.Release_Checks.Fail ("rmdir executable data did not remove directory");
         end if;
      end;

      declare
         Mv_Source : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-mv-source.txt");
         Mv_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-mv-target.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Mv_Source);
         Project_Tools.Files.Delete_File_If_Present (Mv_Target);
         Project_Tools.Files.Write_Raw_File (Mv_Source, "move-data");
         Expect_Output
           ("mv executable data",
            Built_Command_Path ("mv"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Mv_Source),
                                                Project_Tools.Processes.Argument (Mv_Target)]),
            0,
            "");
         Expect_File ("mv executable data", Mv_Target, "move-data");
         Project_Tools.Files.Delete_File_If_Present (Mv_Target);
      end;

      declare
         Rm_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-rm.txt");
      begin
         Project_Tools.Files.Write_Raw_File (Rm_Target, "remove-data");
         Expect_Output
           ("rm executable data",
            Built_Command_Path ("rm"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Rm_Target)]),
            0,
            "");
         if Project_Tools.Files.File_Exists (Rm_Target) then
            Project_Tools.Release_Checks.Fail ("rm executable data did not remove file");
         end if;
      end;

      Expect_Nonempty_Line
        ("pwd executable data",
         Built_Command_Path ("pwd"),
         Project_Tools.Processes.No_Arguments);

      Project_Tools.Files.Write_Raw_File (Smoke_File, "beta" & LF & "alpha");
      Expect_Output
        ("sort executable data",
         Built_Command_Path ("sort"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF & "beta" & LF);
      Project_Tools.Files.Write_Raw_File (Smoke_File, "alpha" & LF & "beta" & LF);

      Expect_Output
        ("tail executable data",
         Built_Command_Path ("tail"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("-n"),
             Project_Tools.Processes.Argument ("1"),
             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "beta" & LF);

      Expect_Output
        ("true executable status",
         Built_Command_Path ("true"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("ignored")]),
         0,
         "");

      declare
         Tee_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-tee.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Tee_Target);
         Expect_Output_With_Input
           ("tee executable data",
            Built_Command_Path ("tee"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Tee_Target)]),
            "tee-data",
            0,
            "tee-data");
         Expect_File ("tee executable data", Tee_Target, "tee-data" & LF);
         Project_Tools.Files.Delete_File_If_Present (Tee_Target);
      end;

      Expect_Output
        ("test executable status",
         Built_Command_Path ("test"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-f"),
                                             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "");

      declare
         Touch_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-touch.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Touch_Target);
         Expect_Output
           ("touch executable data",
            Built_Command_Path ("touch"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Touch_Target)]),
            0,
            "");
         Expect_File ("touch executable data", Touch_Target, "");
         Project_Tools.Files.Delete_File_If_Present (Touch_Target);
      end;

      Expect_Output_With_Input
        ("tr executable data",
         Built_Command_Path ("tr"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("a-z"),
             Project_Tools.Processes.Argument ("A-Z")]),
         "alpha",
         0,
         "ALPHA");

      Expect_Output_With_Input
        ("uniq executable data",
         Built_Command_Path ("uniq"),
         Project_Tools.Processes.No_Arguments,
         "alpha" & LF & "alpha" & LF & "beta",
         0,
         "alpha" & LF & "beta");

      Expect_Output_With_Input
        ("xargs executable data",
         Built_Command_Path ("xargs"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-r")]),
         "",
         0,
         "");

      Expect_Output
        ("wc executable data",
         Built_Command_Path ("wc"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("-c"),
             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "11 " & Smoke_File & LF);

      Project_Tools.Files.Delete_File_If_Present (Smoke_File);

      Ada.Text_IO.Put_Line ("executable integration smoke checks passed");
   end Run_Executable_Integration_Smoke;

   function Suite_Filter (Name : String) return String is
   begin
      if Name = "basic" or else Name = "common" then
         return "basic:";
      elsif Name = "streams" then
         return "streams:";
      elsif Name = "regression" then
         return "regression:";
      elsif Name = "locale" then
         return "locale:";
      elsif Name = "presentation" then
         return "presentation:";
      elsif Name = "command" or else Name = "commands" then
         return "command:";
      elsif Name = "root" or else Name = "posix-tools" then
         return "command:root";
      elsif Posix_Tools.Command_Inventory.Contains_Executable (Name) then
         return "command:" & Name;
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "posix_tools_tests: suite '" & Name & "' has no registered AUnit tests yet");
         raise Invalid_Usage;
      end if;
   end Suite_Filter;

   function Test_Filter_Text return String is
      use Ada.Strings.Unbounded;
      Filter_Text : Unbounded_String;
      I           : Positive := 2;
   begin
      if Command /= "test" then
         return "";
      end if;

      while I <= Ada.Command_Line.Argument_Count loop
         if Ada.Command_Line.Argument (I) = "--suite"
           and then I < Ada.Command_Line.Argument_Count
         then
            Filter_Text := To_Unbounded_String (Suite_Filter (Ada.Command_Line.Argument (I + 1)));
            I := I + 2;
         elsif Ada.Command_Line.Argument (I) = "--category"
           and then I < Ada.Command_Line.Argument_Count
         then
            if Ada.Command_Line.Argument (I + 1) = "unit" then
               Filter_Text := Null_Unbounded_String;
            elsif Ada.Command_Line.Argument (I + 1) = "integration" then
               Filter_Text := To_Unbounded_String ("command:root");
            elsif Ada.Command_Line.Argument (I + 1) = "conformance" then
               Filter_Text := To_Unbounded_String ("basic:command inventory");
            elsif Ada.Command_Line.Argument (I + 1) = "regression" then
               Filter_Text := To_Unbounded_String ("regression:");
            elsif Ada.Command_Line.Argument (I + 1) = "locale" then
               Filter_Text := To_Unbounded_String ("locale:");
            elsif Ada.Command_Line.Argument (I + 1) = "presentation" then
               Filter_Text := To_Unbounded_String ("presentation:");
            else
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "posix_tools_tests: category '" & Ada.Command_Line.Argument (I + 1)
                  & "' has no registered AUnit tests yet");
               raise Invalid_Usage;
            end if;
            I := I + 2;
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "posix_tools_tests: invalid test option '" & Ada.Command_Line.Argument (I) & "'");
            raise Invalid_Usage;
         end if;
      end loop;

      return To_String (Filter_Text);
   end Test_Filter_Text;

   procedure Run_Tests is
      use type AUnit.Status;
      Filter_Text : constant String := Test_Filter_Text;
   begin
      if Filter_Text /= "" then
         AUnit.Test_Filters.Set_Name (Name_Filter, Filter_Text);
         Options.Filter := Name_Filter'Unchecked_Access;
      else
         Options.Filter := null;
      end if;

      if Runner (Reporter, Options) /= AUnit.Success then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   end Run_Tests;
begin
   if Command = "test"
   then
      Run_Tests;
   elsif Command = "check"
   then
      Run_Metadata_Checks;
      Run_Format_Checks;
      Run_Conformance_Checks;
      Run_Tests;
   elsif Command = "release-check" then
      Generate_Docs;
      Generate_Package_Manifest;
      Run_Build;
      Run_Test_Selector_Smoke;
      Run_Staged_Verification;
      Run_Executable_Integration_Smoke;
      Generate_Release_Archive;
      Run_Metadata_Checks;
      Run_Format_Checks;
      Run_Conformance_Checks;
      Run_Proof_Checks;
      Run_Tests;
   elsif Command = "release" then
      Require_Clean_Source_Tree;
      Generate_Docs;
      Generate_Package_Manifest;
      Run_Build;
      Run_Test_Selector_Smoke;
      Run_Staged_Verification;
      Run_Executable_Integration_Smoke;
      Generate_Release_Archive;
      Generate_Release_Checksums;
      Run_Metadata_Checks;
      Run_Format_Checks;
      Run_Conformance_Checks;
      Run_Proof_Checks;
      Run_Tests;
      Ada.Text_IO.Put_Line ("release: completed by Ada project_tools driver");
   elsif Command = "build"
   then
      Run_Build;
      Run_Metadata_Checks;
      Ada.Text_IO.Put_Line (Command & ": completed by Ada project_tools driver");
   elsif Command = "conformance" then
      Run_Metadata_Checks;
      Run_Conformance_Checks;
      Ada.Text_IO.Put_Line ("conformance: completed by Ada project_tools driver");
   elsif Command = "format-check"
   then
      Run_Metadata_Checks;
      Run_Format_Checks;
      Ada.Text_IO.Put_Line (Command & ": completed by Ada project_tools driver");
   elsif Command = "docs" then
      Generate_Docs;
      Run_Metadata_Checks;
      Ada.Text_IO.Put_Line ("docs: completed by Ada project_tools driver");
   elsif Command = "prove" then
      Run_Metadata_Checks;
      Run_Proof_Checks;
      Ada.Text_IO.Put_Line ("prove: completed by Ada project_tools driver");
   elsif Command = "package" then
      Generate_Package_Manifest;
      Generate_Release_Archive;
      Run_Metadata_Checks;
      Ada.Text_IO.Put_Line ("package: completed by Ada project_tools driver");
   else
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "posix_tools_tests: unknown command '" & Command & "'");
      Ada.Command_Line.Set_Exit_Status (2);
   end if;
exception
   when Invalid_Usage =>
      Ada.Command_Line.Set_Exit_Status (2);
   when Program_Error =>
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
