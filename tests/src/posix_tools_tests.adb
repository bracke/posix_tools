with Ada.Command_Line;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Options;
with AUnit.Reporter.Text;
with AUnit.Run;
with AUnit.Test_Filters;
with All_Suites;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Host_Adapters.Executables;
with Posix_Tools.Version;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;
with Project_Tools.Text;

procedure Posix_Tools_Tests is
   procedure Runner is new AUnit.Run.Test_Runner (All_Suites.Suite);

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

   function Root return String is
   begin
      if Project_Tools.Files.File_Exists ("alire.toml")
        and then Project_Tools.Files.Directory_Exists ("common")
      then
         return ".";
      else
         return "..";
      end if;
   end Root;

   procedure Run_Metadata_Checks is
      Check : constant Project_Tools.Release_Checks.Checker :=
        Project_Tools.Release_Checks.Create (Root);
      Root_Manifest : constant String :=
        Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "alire.toml"));

      procedure Require_Synchronized_Version (Path : String) is
      begin
         Project_Tools.Release_Checks.Require_Text
           (Check, Path, Posix_Tools.Version.Version_String);
      end Require_Synchronized_Version;

      procedure Forbid_Text (Path : String; Text : String; Message : String) is
      begin
         if Project_Tools.Files.File_Contains (Project_Tools.Files.Join (Root, Path), Text) then
            Project_Tools.Release_Checks.Fail (Message);
         end if;
      end Forbid_Text;

      procedure Require_Command_Doc_Sections (Path : String) is
         procedure Require_Section (Heading : String) is
         begin
            Project_Tools.Release_Checks.Require_Text
              (Check,
               Path,
               Character'Val (10) & "## " & Heading & Character'Val (10));
         end Require_Section;
      begin
         Require_Section ("Name");
         Require_Section ("Synopsis");
         Require_Section ("Description");
         Require_Section ("Operands");
         Require_Section ("Options");
         Require_Section ("Standard Input");
         Require_Section ("Standard Output");
         Require_Section ("Standard Error");
         Require_Section ("Exit Status");
         Require_Section ("Behavioral Details");
         Require_Section ("Locale Behavior");
         Require_Section ("Implementation-Defined Choices");
         Require_Section ("Extensions");
         Require_Section ("Examples");
         Require_Section ("Conformance Status");
         Require_Section ("Known Limitations");
      end Require_Command_Doc_Sections;

      function Boolean_Text (Value : Boolean) return String is
      begin
         if Value then
            return "true";
         else
            return "false";
         end if;
      end Boolean_Text;

      function Expected_Command_Inventory return String is
         use Ada.Strings.Unbounded;
         Content : Unbounded_String;
      begin
         Append
           (Content,
            "executable,crate,package,manifest_path,project_file_path,documentation_path,"
            & "release_included,posix_status,help,version,identity"
            & Character'Val (10));

         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            Append
              (Content,
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

         return To_String (Content);
      end Expected_Command_Inventory;

      procedure Require_Command_Inventory_Current is
         Path     : constant String := "generated/command_inventory.csv";
         Actual   : constant String := Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));
         Expected : constant String := Expected_Command_Inventory;
      begin
         if Actual /= Expected then
            Project_Tools.Release_Checks.Fail ("generated command inventory is stale");
         end if;
      end Require_Command_Inventory_Current;

      function Expected_Manpage (Index : Positive) return String is
         use Ada.Strings.Unbounded;
         Command : constant String := Posix_Tools.Command_Inventory.Executable (Index);
         Page    : Unbounded_String;
      begin
         Append (Page, ".TH " & Command & " 1" & Character'Val (10));
         Append (Page, ".SH NAME" & Character'Val (10));
         Append (Page, Command & " - posix-tools command" & Character'Val (10));
         Append (Page, ".SH SYNOPSIS" & Character'Val (10));
         Append (Page, Command & " [--help] [--version]" & Character'Val (10));
         Append (Page, ".SH DESCRIPTION" & Character'Val (10));
         Append
           (Page,
            "Generated manual page for " & Command & " from the posix-tools "
            & Posix_Tools.Version.Version_String & " command inventory."
            & Character'Val (10));
         Append (Page, ".SH CONFORMANCE" & Character'Val (10));
         Append (Page, Posix_Tools.Command_Inventory.Posix_Status (Index) & Character'Val (10));
         Append (Page, ".SH SEE ALSO" & Character'Val (10));
         Append (Page, Posix_Tools.Command_Inventory.Documentation_Path (Index) & Character'Val (10));
         Append (Page, Character'Val (10));

         return To_String (Page);
      end Expected_Manpage;

      function Expected_Root_Manpage return String is
         use Ada.Strings.Unbounded;
         Page : Unbounded_String;
      begin
         Append (Page, ".TH posix-tools 1" & Character'Val (10));
         Append (Page, ".SH NAME" & Character'Val (10));
         Append (Page, "posix-tools - manage the posix-tools executable suite" & Character'Val (10));
         Append (Page, ".SH SYNOPSIS" & Character'Val (10));
         Append (Page, "posix-tools help|version|list|paths|verify" & Character'Val (10));
         Append (Page, ".SH DESCRIPTION" & Character'Val (10));
         Append
           (Page,
            "Generated manual page for the posix-tools "
            & Posix_Tools.Version.Version_String
            & " root management executable. This executable is outside POSIX conformance claims."
            & Character'Val (10));
         Append (Page, ".SH SEE ALSO" & Character'Val (10));
         Append (Page, "docs/commands/posix-tools.md" & Character'Val (10));
         Append (Page, Character'Val (10));

         return To_String (Page);
      end Expected_Root_Manpage;

      function Expected_Manual_Index return String is
         use Ada.Strings.Unbounded;
         Content : Unbounded_String;
      begin
         Append (Content, "# Generated Manual Index" & Character'Val (10) & Character'Val (10));
         Append
           (Content,
            "Version: " & Posix_Tools.Version.Version_String
            & Character'Val (10) & Character'Val (10));

         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            Append
              (Content,
               "- `" & Posix_Tools.Command_Inventory.Executable (I) & "`: "
               & Posix_Tools.Command_Inventory.Documentation_Path (I)
               & Character'Val (10));
         end loop;

         Append (Content, Character'Val (10));
         return To_String (Content);
      end Expected_Manual_Index;

      procedure Require_File_Equals (Path : String; Expected : String; Message : String) is
         Actual : constant String := Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));

         function Normalize_Line_Endings (Text : String) return String is
            use Ada.Strings.Unbounded;
            Normalized : Unbounded_String;
         begin
            for Ch of Text loop
               if Ch /= Character'Val (13) then
                  Append (Normalized, Ch);
               end if;
            end loop;

            return To_String (Normalized);
         end Normalize_Line_Endings;
      begin
         if Normalize_Line_Endings (Actual) /= Expected then
            Project_Tools.Release_Checks.Fail (Message);
         end if;
      end Require_File_Equals;

      procedure Require_Generated_Docs_Current is
      begin
         Require_File_Equals
           ("generated/manual-index.md",
            Expected_Manual_Index,
            "generated manual index is stale");
         Require_File_Equals
           ("generated/man/posix-tools.1",
            Expected_Root_Manpage,
            "generated root manual page is stale");

         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            declare
               Command : constant String := Posix_Tools.Command_Inventory.Executable (I);
            begin
               Require_File_Equals
                 ("generated/man/" & Command & ".1",
                  Expected_Manpage (I),
                  "generated manual page for " & Command & " is stale");
            end;
         end loop;
      end Require_Generated_Docs_Current;

      function Line_Count (Path : String) return Natural is
         Content : constant String :=
           Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));
         Count   : Natural := 0;
      begin
         for Ch of Content loop
            if Ch = Character'Val (10) then
               Count := Count + 1;
            end if;
         end loop;

         if Content'Length > 0 and then Content (Content'Last) /= Character'Val (10) then
            Count := Count + 1;
         end if;

         return Count;
      end Line_Count;

      function Command_Source_Path (Executable : String) return String is
      begin
         if Executable = "false" then
            return "common/src/posix_tools-commands-false_command.adb";
         elsif Executable = "true" then
            return "common/src/posix_tools-commands-true_command.adb";
         else
            return "common/src/posix_tools-commands-" & Executable & ".adb";
         end if;
      end Command_Source_Path;

      function Simple_Name (Path : String) return String is
      begin
         for I in reverse Path'Range loop
            if Path (I) = '/' or else Path (I) = '\' then
               if I = Path'Last then
                  return "";
               else
                  return Path (I + 1 .. Path'Last);
               end if;
            end if;
         end loop;

         return Path;
      end Simple_Name;

      function Has_Prohibited_Tooling_Name (Path : String) return Boolean is
         Name : constant String := Simple_Name (Path);
      begin
         return Name = "Makefile"
           or else Name = "CMakeLists.txt"
           or else Project_Tools.Text.Ends_With (Name, ".sh")
           or else Project_Tools.Text.Ends_With (Name, ".py")
           or else Project_Tools.Text.Ends_With (Name, ".pl")
           or else Project_Tools.Text.Ends_With (Name, ".rb")
           or else Project_Tools.Text.Ends_With (Name, ".js")
           or else Project_Tools.Text.Ends_With (Name, ".ts")
           or else Project_Tools.Text.Ends_With (Name, ".ps1")
           or else Project_Tools.Text.Ends_With (Name, ".bat")
           or else Project_Tools.Text.Ends_With (Name, ".cmd");
      end Has_Prohibited_Tooling_Name;

      procedure Check_Ada_Only_Tooling is
         use Ada.Strings.Unbounded;
         Files : constant Project_Tools.Files.Path_List :=
           Project_Tools.Files.List_Tree
             (Root,
              Skip_Entries =>
                [To_Unbounded_String (".git"),
                 To_Unbounded_String ("alire"),
                 To_Unbounded_String ("bin"),
                 To_Unbounded_String ("config"),
                 To_Unbounded_String ("fixtures"),
                 To_Unbounded_String ("lib"),
                 To_Unbounded_String ("obj")]);
      begin
         for Path of Files loop
            declare
               File_Path : constant String := To_String (Path);
            begin
               if Has_Prohibited_Tooling_Name (File_Path) then
                  Project_Tools.Release_Checks.Fail
                    ("project tooling must be Ada/project_tools only; prohibited file " & File_Path);
               end if;
            end;
         end loop;
      end Check_Ada_Only_Tooling;

      procedure Check_No_Silent_Broad_Handlers is
         use Ada.Strings.Unbounded;
         Silent_Handler_Token : constant String := "when others " & "=" & "> null";
         Source_Roots : constant Project_Tools.Files.Name_List :=
           [To_Unbounded_String ("common/src"),
            To_Unbounded_String ("src"),
            To_Unbounded_String ("tests/src"),
            To_Unbounded_String ("tools")];
      begin
         for Source_Root of Source_Roots loop
            for Path of Project_Tools.Files.List_Tree (Project_Tools.Files.Join (Root, To_String (Source_Root))) loop
               declare
                  File_Path : constant String := To_String (Path);
               begin
                  if (Project_Tools.Text.Ends_With (File_Path, ".adb")
                      or else Project_Tools.Text.Ends_With (File_Path, ".ads"))
                    and then Project_Tools.Files.File_Contains (File_Path, Silent_Handler_Token)
                  then
                     Project_Tools.Release_Checks.Fail
                       ("silent broad exception handler is prohibited in " & File_Path);
                  end if;
               end;
            end loop;
         end loop;
      end Check_No_Silent_Broad_Handlers;
   begin
      if Project_Tools.Files.File_Contains
        (Project_Tools.Files.Join (Root, "alire.toml"), "i18n =")
        or else Project_Tools.Files.File_Contains
          (Project_Tools.Files.Join (Root, "alire.toml"), "hostkit =")
        or else Project_Tools.Files.File_Contains
          (Project_Tools.Files.Join (Root, "alire.toml"), "messages =")
        or else Project_Tools.Files.File_Contains
          (Project_Tools.Files.Join (Root, "alire.toml"), "terminal_styles =")
      then
         Project_Tools.Release_Checks.Fail ("root manifest has prohibited direct external dependency");
      end if;

      if Root_Manifest = "" then
         Project_Tools.Release_Checks.Fail ("root manifest could not be read");
      end if;

      Project_Tools.Release_Checks.Require_Text (Check, "alire.toml", "executables = [""posix-tools""]");
      Project_Tools.Release_Checks.Require_Text (Check, "posix_tools.gpr", "for Main use (""posix-tools.adb"")");
      Project_Tools.Release_Checks.Require_Text
        (Check, "alire.toml", "posix_tools_common = { path = ""common"" }");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Forbid_Text
           ("alire.toml",
            Posix_Tools.Command_Inventory.Crate (I) & " =",
            "root manifest must not depend on command crate "
            & Posix_Tools.Command_Inventory.Crate (I));
      end loop;
      if Project_Tools.Files.File_Contains
        (Project_Tools.Files.Join (Root, "common/alire.toml"), "i18n =")
        or else Project_Tools.Files.File_Contains
          (Project_Tools.Files.Join (Root, "common/posix_tools_common.gpr"), "i18n.gpr")
      then
         Project_Tools.Release_Checks.Fail ("common crate has prohibited direct i18n dependency");
      end if;

      Project_Tools.Release_Checks.Require_File (Check, "alire.toml");
      Project_Tools.Release_Checks.Require_File (Check, ".gitattributes");
      Project_Tools.Release_Checks.Require_File (Check, "posix_tools.gpr");
      Project_Tools.Release_Checks.Require_Text (Check, "posix_tools.gpr", "for Object_Dir use ""obj/root""");
      Project_Tools.Release_Checks.Require_Text (Check, "posix_tools.gpr", "for Exec_Dir use ""bin""");
      Project_Tools.Release_Checks.Require_File (Check, "common/alire.toml");
      Project_Tools.Release_Checks.Require_File (Check, "common/posix_tools_common.gpr");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/posix_tools_common.gpr", "for Object_Dir use ""obj/common""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/posix_tools_common.gpr", "for Library_Dir use ""lib""");
      Project_Tools.Release_Checks.Require_File (Check, "common/messages/posix_tools.catalog");
      Project_Tools.Release_Checks.Require_File (Check, "common/src/posix_tools-localization.ads");
      Project_Tools.Release_Checks.Require_File (Check, "common/src/posix_tools-presentation.ads");
      Project_Tools.Release_Checks.Require_File (Check, "common/src/posix_tools-host_adapters-terminals.ads");
      Project_Tools.Release_Checks.Require_File (Check, "common/src/posix_tools-text.ads");
      Project_Tools.Release_Checks.Require_File (Check, "common/src/posix_tools-text-classification.ads");
      Project_Tools.Release_Checks.Require_File (Check, "common/src/posix_tools-text-utf_8.ads");
      Project_Tools.Release_Checks.Require_File (Check, "tests/alire.toml");
      Project_Tools.Release_Checks.Require_File (Check, "tests/posix_tools_tests.gpr");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/posix_tools_tests.gpr", "for Object_Dir use ""obj/tests""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/posix_tools_tests.gpr", "for Exec_Dir use ""bin""");
      Project_Tools.Release_Checks.Require_File (Check, "generated/command_inventory.csv");
      Require_Command_Inventory_Current;
      Project_Tools.Release_Checks.Require_File (Check, "generated/manual-index.md");
      Project_Tools.Release_Checks.Require_File (Check, "generated/man/posix-tools.1");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Project_Tools.Release_Checks.Require_File
           (Check, "generated/man/" & Posix_Tools.Command_Inventory.Executable (I) & ".1");
      end loop;
      Require_Generated_Docs_Current;
      Project_Tools.Release_Checks.Require_File (Check, "generated/package-manifest.txt");
      Project_Tools.Release_Checks.Require_File (Check, "generated/release-checksums.txt");
      Project_Tools.Release_Checks.Require_File (Check, "generated/requirements.csv");
      Project_Tools.Release_Checks.Require_File (Check, "generated/regressions.csv");
      Project_Tools.Release_Checks.Require_File (Check, ".github/workflows/ci.yml");
      Check_Ada_Only_Tooling;
      Check_No_Silent_Broad_Handlers;
      Project_Tools.Release_Checks.Require_File (Check, "docs/ai.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/architecture.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/conformance.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/development.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/portability.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/release-process.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/security.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/testing.md");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Dependency Rules");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Prohibited Imports");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Rejected Architectures");
      Require_Synchronized_Version ("alire.toml");
      Require_Synchronized_Version ("common/alire.toml");
      Require_Synchronized_Version ("tests/alire.toml");
      Require_Synchronized_Version ("common/src/posix_tools-version.ads");
      Require_Synchronized_Version ("CHANGELOG.md");
      Require_Synchronized_Version ("generated/manual-index.md");
      Require_Synchronized_Version ("generated/package-manifest.txt");
      Require_Synchronized_Version ("generated/release-checksums.txt");
      Project_Tools.Release_Checks.Require_Text (Check, "common/alire.toml", "hostkit =");
      Project_Tools.Release_Checks.Require_Text (Check, "common/alire.toml", "messages =");
      Project_Tools.Release_Checks.Require_Text (Check, "common/alire.toml", "terminal_styles =");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/alire.toml", "hostkit = { path = ""../../hostkit"" }");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/alire.toml", "messages = { path = ""../../messages"" }");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/alire.toml", "terminal_styles = { path = ""../../terminal_styles"" }");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.help.usage = Brug");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.option.unknown");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "en.posix_tools.diagnostic.line_count.invalid");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.file.read_failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.internal_failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.text.invalid_utf8");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.pwd.unavailable");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.resource.count_too_large");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "with Terminal_Styles;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-terminals.adb", "with Hostkit.Host;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Max_Identity_Output_Bytes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "return ""shadowed""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "en.posix_tools.root.status.shadowed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.root.status.shadowed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-environment.adb", "with Ada.Environment_Variables;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.adb", "with Ada.Directories;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.adb", "with Hostkit.Descriptors;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.adb", "Hostkit.Metadata.Same_File");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-file_system.adb",
         "Ada.Streams.Stream_IO",
         "production file adapter must route byte stream operations through hostkit descriptors");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-temporary_storage.ads", "private with Hostkit.Descriptors;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-temporary_storage.adb", "Hostkit.Descriptors.Write");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-temporary_storage.adb", "Hostkit.Descriptors.Read");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-temporary_storage.ads",
         "Ada.Streams.Stream_IO",
         "production temporary storage adapter must use hostkit descriptors");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-temporary_storage.adb",
         "Ada.Streams.Stream_IO",
         "production temporary storage adapter must use hostkit descriptors");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-arguments.adb", "with Ada.Command_Line;");
      Forbid_Text
        ("common/src/posix_tools-arguments.adb",
         "Ada.Command_Line",
         "argument value type must not capture process command-line state");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd stale PWD fallback output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.ads", "Try_Physical_Current_Directory");
      Forbid_Text
        ("common/src/posix_tools-commands-pwd.adb",
         "when others",
         "pwd must report expected current-directory failures through context results");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-streams.adb", "Ada.Text_IO.Text_Streams");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "build common crate");
      Project_Tools.Release_Checks.Require_Text
        (Check, "posix_tools.gpr", "for Body (""Posix_Tools_Main"") use ""posix-tools.adb""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tools/false/posix_tools_false.gpr", "for Body (""Posix_Tools_False_Main"") use ""false.adb""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tools/true/posix_tools_true.gpr", "for Body (""Posix_Tools_True_Main"") use ""true.adb""");
      Forbid_Text
        ("common/src/posix_tools-commands-contexts.adb",
         "with Hostkit",
         "command context must use project host adapters instead of hostkit directly");
      Forbid_Text
        ("common/src/posix_tools-commands-contexts.adb",
         "with Ada.Directories",
         "command context must use project filesystem adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-contexts.adb",
         "with Ada.Environment_Variables",
         "command context must use project environment adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-contexts.adb",
         "with Ada.Text_IO",
         "command context must use project stream adapter");
      Forbid_Text
        ("common/src/posix_tools-help.adb",
         "with Terminal_Styles",
         "help renderer must use project presentation adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-root.adb",
         "with Terminal_Styles",
         "root command must use project presentation adapter");
      Project_Tools.Release_Checks.Require_Text (Check, "tests/alire.toml", "posix_tools_common =");
      Project_Tools.Release_Checks.Require_Text (Check, "tests/alire.toml", "aunit =");
      Project_Tools.Release_Checks.Require_Text (Check, "tests/alire.toml", "project_tools =");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/alire.toml", "posix_tools_common = { path = ""../common"" }");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/alire.toml", "project_tools = { path = ""../../project_tools"" }");
      Forbid_Text ("common/alire.toml", "aunit =", "common manifest must not depend on aunit");
      Forbid_Text
        ("common/alire.toml", "project_tools =", "common manifest must not depend on project_tools");
      Forbid_Text
        ("common/src/posix_tools-commands-file_helpers.adb",
         "Ada.Text_IO.Standard_Input",
         "file helpers must read standard input through command context");
      Forbid_Text
        ("common/src/posix_tools-commands-file_helpers.adb",
         "Ada.Streams.Stream_IO",
         "file helpers must use project filesystem adapters for file operands");
      Forbid_Text
        ("common/src/posix_tools-commands-tail.adb",
         "Ada.Text_IO.Standard_Input",
         "tail must read standard input through command context");
      Forbid_Text
        ("common/src/posix_tools-commands-tail.adb",
         "Ada.Streams.Stream_IO",
         "tail command must use shared file helpers for file chunk iteration");
      Forbid_Text
        ("common/src/posix_tools-commands-wc.adb",
         "Ada.Text_IO.Standard_Input",
         "wc must read standard input through command context");
      Forbid_Text
        ("common/src/posix_tools-commands-wc.adb",
         "Ada.Streams.Stream_IO",
         "wc command must use shared file helpers for file chunk iteration");
      Forbid_Text
        ("common/src/posix_tools-commands-head.adb",
         "Requested : Posix_Tools.Numbers.Count := 10;",
         "head must not keep requested line count in package-level mutable state");
      Forbid_Text
        ("common/src/posix_tools-commands-tail.adb",
         "Seen      : Posix_Tools.Numbers.Count := 0;",
         "tail must not keep line position in package-level mutable state");
      Forbid_Text
        ("common/src/posix_tools-commands-tail.adb",
         "Buffer    : Lines.Vector;",
         "tail must not keep retained lines in package-level mutable state");
      Project_Tools.Release_Checks.Require_Directory (Check, "docs/commands");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/index.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/basename.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/cat.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/dirname.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/echo.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/false.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/head.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/posix-tools.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/pwd.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/tail.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/true.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/commands/wc.md");
      Require_Command_Doc_Sections ("docs/commands/posix-tools.md");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Require_Command_Doc_Sections (Posix_Tools.Command_Inventory.Documentation_Path (I));
         Project_Tools.Release_Checks.Require_File
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I));
         Require_Synchronized_Version (Posix_Tools.Command_Inventory.Manifest_Path (I));
         Project_Tools.Release_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "posix_tools_common =");
         Project_Tools.Release_Checks.Require_Text
           (Check,
            Posix_Tools.Command_Inventory.Manifest_Path (I),
            "posix_tools_common = { path = ""../../common"" }");
         Project_Tools.Release_Checks.Require_Text
           (Check,
            Posix_Tools.Command_Inventory.Manifest_Path (I),
            "executables = [""" & Posix_Tools.Command_Inventory.Executable (I) & """]");
         Project_Tools.Release_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "licenses = ""MIT""");
         Project_Tools.Release_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "maintainers =");
         Project_Tools.Release_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "[build-profiles]");
         Forbid_Text
           (Posix_Tools.Command_Inventory.Manifest_Path (I),
            "aunit =",
            Posix_Tools.Command_Inventory.Executable (I) & " manifest must not depend on aunit");
         Forbid_Text
           (Posix_Tools.Command_Inventory.Manifest_Path (I),
            "project_tools =",
            Posix_Tools.Command_Inventory.Executable (I) & " manifest must not depend on project_tools");
         Forbid_Text
           (Posix_Tools.Command_Inventory.Manifest_Path (I),
            "hostkit =",
            Posix_Tools.Command_Inventory.Executable (I) & " manifest must not depend on hostkit");
         Forbid_Text
           (Posix_Tools.Command_Inventory.Manifest_Path (I),
            "messages =",
            Posix_Tools.Command_Inventory.Executable (I) & " manifest must not depend on messages");
         Forbid_Text
           (Posix_Tools.Command_Inventory.Manifest_Path (I),
            "terminal_styles =",
            Posix_Tools.Command_Inventory.Executable (I)
            & " manifest must not depend on terminal_styles");
         for J in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            if J /= I then
               Forbid_Text
                 (Posix_Tools.Command_Inventory.Manifest_Path (I),
                  Posix_Tools.Command_Inventory.Crate (J) & " =",
                  Posix_Tools.Command_Inventory.Executable (I)
                  & " manifest must not depend on command crate "
                  & Posix_Tools.Command_Inventory.Crate (J));
            end if;
         end loop;
         Project_Tools.Release_Checks.Require_File
           (Check, Posix_Tools.Command_Inventory.Project_File_Path (I));
         Project_Tools.Release_Checks.Require_Text
           (Check,
            Posix_Tools.Command_Inventory.Project_File_Path (I),
            "for Main use (""" & Posix_Tools.Command_Inventory.Executable (I) & ".adb"")");
         Project_Tools.Release_Checks.Require_Text
           (Check,
            Posix_Tools.Command_Inventory.Project_File_Path (I),
            "for Object_Dir use ""obj/" & Posix_Tools.Command_Inventory.Executable (I) & """");
         Project_Tools.Release_Checks.Require_Text
           (Check,
            Posix_Tools.Command_Inventory.Project_File_Path (I),
            "for Exec_Dir use ""bin""");
         Project_Tools.Release_Checks.Require_File
           (Check, "tools/" & Posix_Tools.Command_Inventory.Executable (I)
            & "/src/" & Posix_Tools.Command_Inventory.Executable (I) & ".adb");
         Project_Tools.Release_Checks.Require_Text
           (Check,
            "tools/" & Posix_Tools.Command_Inventory.Executable (I)
            & "/src/" & Posix_Tools.Command_Inventory.Executable (I) & ".adb",
            "Posix_Tools.Host_Adapters.Run_Command");
         declare
            Wrapper : constant String :=
              "tools/" & Posix_Tools.Command_Inventory.Executable (I)
              & "/src/" & Posix_Tools.Command_Inventory.Executable (I) & ".adb";
            Command_Source : constant String :=
              Command_Source_Path (Posix_Tools.Command_Inventory.Executable (I));
         begin
            if Line_Count (Wrapper) > 20 then
               Project_Tools.Release_Checks.Fail
                 (Posix_Tools.Command_Inventory.Executable (I) & " wrapper is not thin");
            end if;

            Forbid_Text
              (Wrapper, "with Ada.", Posix_Tools.Command_Inventory.Executable (I)
               & " wrapper must not import Ada services directly");
            Forbid_Text
              (Wrapper, "with Hostkit", Posix_Tools.Command_Inventory.Executable (I)
               & " wrapper must not import hostkit directly");
            Forbid_Text
              (Wrapper, "Text_IO", Posix_Tools.Command_Inventory.Executable (I)
               & " wrapper must not perform text I/O");
            Forbid_Text
              (Wrapper, "Stream_IO", Posix_Tools.Command_Inventory.Executable (I)
               & " wrapper must not perform stream I/O");
            Forbid_Text
              (Wrapper, "Command_Line", Posix_Tools.Command_Inventory.Executable (I)
               & " wrapper must not read command-line state directly");

            Forbid_Text
              (Command_Source, "with Hostkit", Posix_Tools.Command_Inventory.Executable (I)
               & " command must use project host adapters instead of hostkit directly");
            Forbid_Text
              (Command_Source, "with Messages", Posix_Tools.Command_Inventory.Executable (I)
               & " command must use localization adapter instead of messages directly");
            Forbid_Text
              (Command_Source, "with Terminal_Styles", Posix_Tools.Command_Inventory.Executable (I)
               & " command must keep styling at presentation boundaries");
            Forbid_Text
              (Command_Source, "with AUnit", Posix_Tools.Command_Inventory.Executable (I)
               & " command must not depend on tests");
            Forbid_Text
              (Command_Source, "with Project_Tools", Posix_Tools.Command_Inventory.Executable (I)
               & " command must not depend on tooling");
         end;
      end loop;
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "POSIX-WC-UTF8-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "TEXT-UTF8-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "TEXT-WHITESPACE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/generated/posix_tools-text-whitespace_data.ads", "Unicode_Version");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/generated/posix_tools-text-whitespace_data.ads", "White_Space_Ranges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-classification.adb", "Whitespace_Data.Is_Whitespace");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "HOST-ADAPTER-FILE-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "NONPOSIX-WC-LINE-LENGTH-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "VERSION-GENERATION-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "POSIX-TAIL-COMPACT-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "STATE-HEAD-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "STATE-TAIL-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-STDIN-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-STDOUT-FAIL-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-STDOUT-FAIL-002");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-CHUNK-ITERATION-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "ROOT-LIST-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "ROOT-VERIFY-BOUNDED-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "ROOT-VERIFY-SHADOWED-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "PLATFORM-CI-001");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/conformance.md", "Linux, Windows, and macOS");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/portability.md", "option prefix is `-`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/portability.md", "end-of-options marker is `--`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/portability.md", "lexical pathname separator is `/`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/portability.md", "POSIX line delimiter is LF");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/portability.md", "executable suffix is `.exe`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/portability.md", "byte-processing mode is binary");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/portability.md", "backslash is an ordinary character");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "DOCS-AI-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "DOCS-MANPAGES-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "DOCS-MANPAGES-CURRENT-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "DOCS-COMMAND-SECTIONS-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "GPR-DIRS-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "RELEASE-CLEAN-TREE-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "TOOLING-ADA-ONLY-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "EXCEPTION-NO-SILENT-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "TOOLING-SELECTOR-SMOKE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "MANIFEST-GRAPH-004");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "LOCAL-PINS-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "PORTABILITY-WINDOWS-001");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "ubuntu-latest");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "macos-15-intel");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "windows-latest");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "posix_tools_tests.exe");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "release-check");
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
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/release-checksums.txt", "manifest generated/package-manifest.txt fnv1a64=");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/release-checksums.txt", "executable bin/posix-tools fnv1a64=");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "README.md");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "alire.toml");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "common/alire.toml");
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
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "tests/alire.toml");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
         Root,
         "tests/src/posix_tools_tests.adb");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
         Root,
         "tests/src/test_contexts.ads");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Project_Tools.Release_Checks.Require_Manifest_Entry
           (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
            Root,
            "tools/" & Posix_Tools.Command_Inventory.Executable (I)
            & "/src/" & Posix_Tools.Command_Inventory.Executable (I) & ".adb");
         Project_Tools.Release_Checks.Require_Manifest_Entry
           (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
            Root,
            "generated/man/" & Posix_Tools.Command_Inventory.Executable (I) & ".1");
         Project_Tools.Release_Checks.Require_Text
           (Check,
            "generated/man/" & Posix_Tools.Command_Inventory.Executable (I) & ".1",
            ".TH " & Posix_Tools.Command_Inventory.Executable (I) & " 1");
         Project_Tools.Release_Checks.Require_Text
           (Check,
            "generated/release-checksums.txt",
            "executable tools/" & Posix_Tools.Command_Inventory.Executable (I)
            & "/bin/" & Posix_Tools.Command_Inventory.Executable (I) & " fnv1a64=");
      end loop;
      Project_Tools.Release_Checks.Require_Text (Check, "README.md", "posix_tools");
      Ada.Text_IO.Put_Line ("metadata checks passed");
   end Run_Metadata_Checks;

   procedure Generate_Docs is
      use Ada.Strings.Unbounded;
      Content : Unbounded_String;
      Base    : constant String := Root;
      Man_Dir : constant String := Project_Tools.Files.Join (Base, "generated/man");

      procedure Generate_Manpage (Index : Positive) is
         Command : constant String := Posix_Tools.Command_Inventory.Executable (Index);
         Page    : Unbounded_String;
      begin
         Append (Page, ".TH " & Command & " 1" & Character'Val (10));
         Append (Page, ".SH NAME" & Character'Val (10));
         Append (Page, Command & " - posix-tools command" & Character'Val (10));
         Append (Page, ".SH SYNOPSIS" & Character'Val (10));
         Append (Page, Command & " [--help] [--version]" & Character'Val (10));
         Append (Page, ".SH DESCRIPTION" & Character'Val (10));
         Append
           (Page,
            "Generated manual page for " & Command & " from the posix-tools "
            & Posix_Tools.Version.Version_String & " command inventory."
            & Character'Val (10));
         Append (Page, ".SH CONFORMANCE" & Character'Val (10));
         Append (Page, Posix_Tools.Command_Inventory.Posix_Status (Index) & Character'Val (10));
         Append (Page, ".SH SEE ALSO" & Character'Val (10));
         Append (Page, Posix_Tools.Command_Inventory.Documentation_Path (Index) & Character'Val (10));

         Project_Tools.Files.Write_Text_File
           (Project_Tools.Files.Join (Man_Dir, Command & ".1"), To_String (Page));
      end Generate_Manpage;

      procedure Generate_Root_Manpage is
         Page : Unbounded_String;
      begin
         Append (Page, ".TH posix-tools 1" & Character'Val (10));
         Append (Page, ".SH NAME" & Character'Val (10));
         Append (Page, "posix-tools - manage the posix-tools executable suite" & Character'Val (10));
         Append (Page, ".SH SYNOPSIS" & Character'Val (10));
         Append (Page, "posix-tools help|version|list|paths|verify" & Character'Val (10));
         Append (Page, ".SH DESCRIPTION" & Character'Val (10));
         Append
           (Page,
            "Generated manual page for the posix-tools "
            & Posix_Tools.Version.Version_String
            & " root management executable. This executable is outside POSIX conformance claims."
            & Character'Val (10));
         Append (Page, ".SH SEE ALSO" & Character'Val (10));
         Append (Page, "docs/commands/posix-tools.md" & Character'Val (10));

         Project_Tools.Files.Write_Text_File
           (Project_Tools.Files.Join (Man_Dir, "posix-tools.1"), To_String (Page));
      end Generate_Root_Manpage;
   begin
      if not Ada.Directories.Exists (Man_Dir) then
         Ada.Directories.Create_Directory (Man_Dir);
      end if;

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

      Project_Tools.Files.Write_Text_File
        (Project_Tools.Files.Join (Base, "generated/manual-index.md"), To_String (Content));
      Ada.Text_IO.Put_Line ("generated/manual-index.md");
      Ada.Text_IO.Put_Line ("generated/man/*.1");
   end Generate_Docs;

   procedure Generate_Package_Manifest is
      use Ada.Strings.Unbounded;
      Content : Unbounded_String;
      Base    : constant String := Root;

      procedure Add_Entry (Relative_Path : String) is
      begin
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
      Add_Entry (".gitattributes");
      Add_Entry ("alire.toml");
      Add_Entry ("posix_tools.gpr");
      Add_Entry ("README.md");
      Add_Entry ("LICENSE");
      Add_Entry (".github/workflows/ci.yml");
      Add_Entry ("generated/command_inventory.csv");
      Add_Entry ("generated/requirements.csv");
      Add_Entry ("generated/regressions.csv");
      Add_Entry ("generated/manual-index.md");
      Add_Entry ("generated/man/posix-tools.1");
      Add_Entry ("CHANGELOG.md");
      Add_Entry ("SECURITY.md");
      Add_Entry ("docs/ai.md");
      Add_Entry ("docs/architecture.md");
      Add_Entry ("docs/conformance.md");
      Add_Entry ("docs/development.md");
      Add_Entry ("docs/portability.md");
      Add_Entry ("docs/release-process.md");
      Add_Entry ("docs/security.md");
      Add_Entry ("docs/testing.md");
      Add_Entry ("src/posix-tools.adb");
      Add_Entry ("common/alire.toml");
      Add_Entry ("common/posix_tools_common.gpr");
      Add_Entry ("common/src/posix_tools.ads");
      Add_Entry ("common/src/posix_tools-arguments.adb");
      Add_Entry ("common/src/posix_tools-arguments.ads");
      Add_Entry ("common/src/posix_tools-arguments-parsing.adb");
      Add_Entry ("common/src/posix_tools-arguments-parsing.ads");
      Add_Entry ("common/src/posix_tools-command_inventory.adb");
      Add_Entry ("common/src/posix_tools-command_inventory.ads");
      Add_Entry ("common/src/posix_tools-commands.ads");
      Add_Entry ("common/src/posix_tools-commands-basename.adb");
      Add_Entry ("common/src/posix_tools-commands-basename.ads");
      Add_Entry ("common/src/posix_tools-commands-cat.adb");
      Add_Entry ("common/src/posix_tools-commands-cat.ads");
      Add_Entry ("common/src/posix_tools-commands-contexts.adb");
      Add_Entry ("common/src/posix_tools-commands-contexts.ads");
      Add_Entry ("common/src/posix_tools-commands-dirname.adb");
      Add_Entry ("common/src/posix_tools-commands-dirname.ads");
      Add_Entry ("common/src/posix_tools-commands-echo.adb");
      Add_Entry ("common/src/posix_tools-commands-echo.ads");
      Add_Entry ("common/src/posix_tools-commands-false_command.adb");
      Add_Entry ("common/src/posix_tools-commands-false_command.ads");
      Add_Entry ("common/src/posix_tools-commands-file_helpers.adb");
      Add_Entry ("common/src/posix_tools-commands-file_helpers.ads");
      Add_Entry ("common/src/posix_tools-commands-head.adb");
      Add_Entry ("common/src/posix_tools-commands-head.ads");
      Add_Entry ("common/src/posix_tools-commands-helpers.adb");
      Add_Entry ("common/src/posix_tools-commands-helpers.ads");
      Add_Entry ("common/src/posix_tools-commands-pwd.adb");
      Add_Entry ("common/src/posix_tools-commands-pwd.ads");
      Add_Entry ("common/src/posix_tools-commands-results.ads");
      Add_Entry ("common/src/posix_tools-commands-root.adb");
      Add_Entry ("common/src/posix_tools-commands-root.ads");
      Add_Entry ("common/src/posix_tools-commands-tail.adb");
      Add_Entry ("common/src/posix_tools-commands-tail.ads");
      Add_Entry ("common/src/posix_tools-commands-true_command.adb");
      Add_Entry ("common/src/posix_tools-commands-true_command.ads");
      Add_Entry ("common/src/posix_tools-commands-wc.adb");
      Add_Entry ("common/src/posix_tools-commands-wc.ads");
      Add_Entry ("common/src/posix_tools-exit_status.ads");
      Add_Entry ("common/src/posix_tools-help.adb");
      Add_Entry ("common/src/posix_tools-help.ads");
      Add_Entry ("common/src/posix_tools-host_adapters.ads");
      Add_Entry ("common/src/posix_tools-host_adapters-arguments.adb");
      Add_Entry ("common/src/posix_tools-host_adapters-arguments.ads");
      Add_Entry ("common/src/posix_tools-host_adapters-environment.adb");
      Add_Entry ("common/src/posix_tools-host_adapters-environment.ads");
      Add_Entry ("common/src/posix_tools-host_adapters-executables.adb");
      Add_Entry ("common/src/posix_tools-host_adapters-executables.ads");
      Add_Entry ("common/src/posix_tools-host_adapters-file_system.adb");
      Add_Entry ("common/src/posix_tools-host_adapters-file_system.ads");
      Add_Entry ("common/src/posix_tools-host_adapters-run_command.adb");
      Add_Entry ("common/src/posix_tools-host_adapters-run_command.ads");
      Add_Entry ("common/src/posix_tools-host_adapters-streams.adb");
      Add_Entry ("common/src/posix_tools-host_adapters-streams.ads");
      Add_Entry ("common/src/posix_tools-host_adapters-terminals.adb");
      Add_Entry ("common/src/posix_tools-host_adapters-terminals.ads");
      Add_Entry ("common/src/posix_tools-host_adapters-temporary_storage.adb");
      Add_Entry ("common/src/posix_tools-host_adapters-temporary_storage.ads");
      Add_Entry ("common/src/posix_tools-localization.adb");
      Add_Entry ("common/src/posix_tools-localization.ads");
      Add_Entry ("common/src/posix_tools-numbers.adb");
      Add_Entry ("common/src/posix_tools-numbers.ads");
      Add_Entry ("common/src/posix_tools-paths.adb");
      Add_Entry ("common/src/posix_tools-paths.ads");
      Add_Entry ("common/src/posix_tools-presentation.adb");
      Add_Entry ("common/src/posix_tools-presentation.ads");
      Add_Entry ("common/src/posix_tools-streams.ads");
      Add_Entry ("common/src/posix_tools-streams-counting.adb");
      Add_Entry ("common/src/posix_tools-streams-counting.ads");
      Add_Entry ("common/src/posix_tools-streams-lines.adb");
      Add_Entry ("common/src/posix_tools-streams-lines.ads");
      Add_Entry ("common/src/posix_tools-text.ads");
      Add_Entry ("common/src/posix_tools-text-classification.adb");
      Add_Entry ("common/src/posix_tools-text-classification.ads");
      Add_Entry ("common/src/posix_tools-text-utf_8.adb");
      Add_Entry ("common/src/posix_tools-text-utf_8.ads");
      Add_Entry ("common/generated/posix_tools-text-whitespace_data.adb");
      Add_Entry ("common/generated/posix_tools-text-whitespace_data.ads");
      Add_Entry ("common/src/posix_tools-version.ads");
      Add_Entry ("common/messages/posix_tools.catalog");
      Add_Entry ("tests/alire.toml");
      Add_Entry ("tests/posix_tools_tests.gpr");
      Add_Entry ("tests/src/all_suites.adb");
      Add_Entry ("tests/src/all_suites.ads");
      Add_Entry ("tests/src/basic_tests-suite.adb");
      Add_Entry ("tests/src/basic_tests-suite.ads");
      Add_Entry ("tests/src/basic_tests.adb");
      Add_Entry ("tests/src/basic_tests.ads");
      Add_Entry ("tests/src/command_tests-suite.adb");
      Add_Entry ("tests/src/command_tests-suite.ads");
      Add_Entry ("tests/src/command_tests.adb");
      Add_Entry ("tests/src/command_tests.ads");
      Add_Entry ("tests/src/posix_tools_tests.adb");
      Add_Entry ("tests/src/test_contexts.adb");
      Add_Entry ("tests/src/test_contexts.ads");
      Add_Entry ("fixtures/reg-tail-byte-spill.bin");

      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Add_Entry ("generated/man/" & Posix_Tools.Command_Inventory.Executable (I) & ".1");
         Add_Entry (Posix_Tools.Command_Inventory.Manifest_Path (I));
         Add_Entry (Posix_Tools.Command_Inventory.Project_File_Path (I));
         Add_Entry
           ("tools/" & Posix_Tools.Command_Inventory.Executable (I)
            & "/src/" & Posix_Tools.Command_Inventory.Executable (I) & ".adb");
         Add_Entry (Posix_Tools.Command_Inventory.Documentation_Path (I));
      end loop;

      Project_Tools.Files.Write_Text_File
        (Project_Tools.Files.Join (Base, "generated/package-manifest.txt"), To_String (Content));
      Ada.Text_IO.Put_Line ("generated/package-manifest.txt");
   end Generate_Package_Manifest;

   procedure Generate_Release_Checksums is
      use Ada.Strings.Unbounded;
      Content : Unbounded_String;
      Base    : constant String := Root;

      procedure Add_File (Label : String; Path : String) is
      begin
         Append
           (Content,
            Label & " " & Path
            & " fnv1a64=" & Project_Tools.Release_Checks.FNV1A64 (Project_Tools.Files.Join (Base, Path))
            & Character'Val (10));
      end Add_File;
   begin
      Append
        (Content,
         "posix-tools release checksums " & Posix_Tools.Version.Version_String
         & Character'Val (10));
      Add_File ("manifest", "generated/package-manifest.txt");

      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Add_File
           ("executable",
            "tools/" & Posix_Tools.Command_Inventory.Executable (I)
            & "/bin/" & Posix_Tools.Command_Inventory.Executable (I));
      end loop;

      Add_File ("executable", "bin/posix-tools");

      Project_Tools.Files.Write_Text_File
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

      function Without_Trailing_CR (Line : String) return String is
      begin
         if Line'Length > 0 and then Line (Line'Last) = Character'Val (13) then
            return Line (Line'First .. Line'Last - 1);
         else
            return Line;
         end if;
      end Without_Trailing_CR;

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
            elsif not (Ch in 'A' .. 'Z' or else Ch in '0' .. '9') then
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
           or else Text (Text'First .. Text'First + Prefix'Length - 1) /= Prefix
         then
            return False;
         end if;

         for I in Text'First + Prefix'Length .. Text'Last loop
            if Text (I) = '-' then
               Last_Hyphen := I;
            elsif not (Text (I) in 'A' .. 'Z' or else Text (I) in '0' .. '9') then
               return False;
            end if;
         end loop;

         if Last_Hyphen = 0
           or else Text'Last - Last_Hyphen /= 4
         then
            return False;
         end if;

         for I in Last_Hyphen + 1 .. Text'Last loop
            if not (Text (I) in '0' .. '9') then
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
             (Project_Tools.Files.Join (Root, "tests/src/command_tests-suite.adb"), Needle);
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
           or else Reference = "posix_tools_tests release"
           or else Reference = "posix_tools_tests release-check"
           or else Reference = "posix_tools_tests test --category integration"
           or else Reference = "posix_tools_tests test --suite cat"
           or else Reference = "posix_tools_tests test --suite command"
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
         Wrapper_Path : constant String :=
           "tools/" & Executable & "/src/" & Executable & ".adb";
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
         Check_Inventory_Path (Executable, Wrapper_Path, "wrapper source path");
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

      function Starts_At (Text : String; Position : Positive; Prefix : String) return Boolean is
      begin
         return Position + Prefix'Length - 1 <= Text'Last
           and then Text (Position .. Position + Prefix'Length - 1) = Prefix;
      end Starts_At;

      function First_Doc_Path (Text : String) return String is
      begin
         for I in Text'Range loop
            if Starts_At (Text, I, "docs/") then
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
                     Line : constant String := Without_Trailing_CR (Requirements (Start .. I - 1));
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
               Line : constant String := Without_Trailing_CR (Requirements (Start .. Requirements'Last));
            begin
               return Field (Line, 1) /= "id"
                 and then Contains_Token (Field (Line, 2), Executable);
            end;
         end if;

         return False;
      end Has_Command_Metadata;

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
                     Line : constant String := Without_Trailing_CR (Requirements (Start .. I - 1));
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
               Line : constant String := Without_Trailing_CR (Requirements (Start .. Requirements'Last));
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
                     Line : constant String := Without_Trailing_CR (Regressions (Start .. I - 1));
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
               Line : constant String := Without_Trailing_CR (Regressions (Start .. Regressions'Last));
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
                     Line : constant String := Without_Trailing_CR (Inventory_Csv (Start .. I - 1));
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
               Line : constant String := Without_Trailing_CR (Inventory_Csv (Start .. Inventory_Csv'Last));
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
      end loop;
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "Known deviation");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/conformance.md", "POSIX.1-2024");
      Ada.Text_IO.Put_Line ("conformance metadata checks passed");
   end Run_Conformance_Checks;

   function Ends_With (Text : String; Suffix : String) return Boolean is
   begin
      return Text'Length >= Suffix'Length
        and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix;
   end Ends_With;

   function Is_Checked_Text_File (Path : String) return Boolean is
   begin
      return Ends_With (Path, ".adb")
        or else Ends_With (Path, ".ads")
        or else Ends_With (Path, ".gpr")
        or else Ends_With (Path, ".toml")
        or else Ends_With (Path, ".md")
        or else Ends_With (Path, ".csv")
        or else Ends_With (Path, ".txt");
   end Is_Checked_Text_File;

   function Has_Tab (Text : String) return Boolean is
   begin
      for Ch of Text loop
         if Ch = Character'Val (9) then
            return True;
         end if;
      end loop;

      return False;
   end Has_Tab;

   function Has_Trailing_Whitespace (Text : String) return Boolean is
      Line_Last : Natural := 0;
   begin
      for I in Text'Range loop
         if Text (I) = Character'Val (10) then
            declare
               Last : Natural := I - 1;
            begin
               if Last >= Text'First and then Text (Last) = Character'Val (13) then
                  Last := Last - 1;
               end if;

               if Last >= Line_Last
                 and then (Text (Last) = ' ' or else Text (Last) = Character'Val (9))
               then
                  return True;
               end if;
            end;
            Line_Last := I + 1;
         end if;
      end loop;

      return Text'Length > 0
        and then (Text (Text'Last) = ' ' or else Text (Text'Last) = Character'Val (9));
   end Has_Trailing_Whitespace;

   function Has_Multiple_Blank_Lines (Text : String) return Boolean is
      Previous_Blank : Boolean := False;
      Line_Has_Text  : Boolean := False;
   begin
      for Ch of Text loop
         if Ch = Character'Val (10) then
            if not Line_Has_Text then
               if Previous_Blank then
                  return True;
               end if;
               Previous_Blank := True;
            else
               Previous_Blank := False;
            end if;

            Line_Has_Text := False;
         elsif Ch /= Character'Val (13) then
            Line_Has_Text := True;
         end if;
      end loop;

      return False;
   end Has_Multiple_Blank_Lines;

   procedure Run_Format_Checks is
      use Ada.Strings.Unbounded;
      Base : constant String := Root;
      Files : constant Project_Tools.Files.Path_List :=
        Project_Tools.Files.List_Tree
          (Base,
           Skip_Entries =>
             [To_Unbounded_String ("alire"),
              To_Unbounded_String ("bin"),
              To_Unbounded_String ("config"),
              To_Unbounded_String ("fixtures"),
              To_Unbounded_String ("lib"),
              To_Unbounded_String ("obj")]);
   begin
      for Path of Files loop
         declare
            File_Path : constant String := To_String (Path);
         begin
            if Is_Checked_Text_File (File_Path) then
               declare
                  Content : constant String := Project_Tools.Files.Read_Raw_File (File_Path);
               begin
                  if Has_Tab (Content) then
                     Project_Tools.Release_Checks.Fail ("tab character in " & File_Path);
                  elsif Has_Trailing_Whitespace (Content) then
                     Project_Tools.Release_Checks.Fail ("trailing whitespace in " & File_Path);
                  elsif Has_Multiple_Blank_Lines (Content) then
                     Project_Tools.Release_Checks.Fail ("multiple consecutive blank lines in " & File_Path);
                  end if;
               end;
            end if;
         end;
      end loop;

      Ada.Text_IO.Put_Line ("format checks passed");
   end Run_Format_Checks;

   procedure Build_Crate (Alire : String; Directory : String; Label : String) is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          (Label   => Label,
           Dir     => Directory,
           Program => Alire,
           Args    => Project_Tools.Processes.Arguments
             ([Project_Tools.Processes.Argument ("-n"),
               Project_Tools.Processes.Argument ("build")]));
   begin
      if Status /= 0 then
         Project_Tools.Release_Checks.Fail (Label & " failed");
      end if;
   end Build_Crate;

   procedure Run_Build is
      Base : constant String := Root;
      Alire : constant String := Project_Tools.Processes.Locate_Command ("alr");
   begin
      if Alire = "" then
         Project_Tools.Release_Checks.Fail ("alr command not found");
      end if;

      Build_Crate (Alire, Project_Tools.Files.Join (Base, "common"), "build common crate");
      Build_Crate (Alire, Base, "build root crate");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Build_Crate
           (Alire,
            Project_Tools.Files.Join
              (Base, "tools/" & Posix_Tools.Command_Inventory.Executable (I)),
            "build " & Posix_Tools.Command_Inventory.Executable (I));
      end loop;
      Build_Crate (Alire, Project_Tools.Files.Join (Base, "tests"), "build tests crate");
   end Run_Build;

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
         return Base_Path;
      elsif Project_Tools.Files.File_Exists (Base_Path & ".exe") then
         return Base_Path & ".exe";
      else
         return Base_Path;
      end if;
   end Built_Command_Path;

   function Built_Test_Runner_Path return String is
      Base_Path : constant String := Project_Tools.Files.Join (Root, "tests/bin/posix_tools_tests");
   begin
      if Project_Tools.Files.File_Exists (Base_Path) then
         return Base_Path;
      elsif Project_Tools.Files.File_Exists (Base_Path & ".exe") then
         return Base_Path & ".exe";
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
            Project_Tools.Release_Checks.Fail
              (Label & " failed with status" & Integer'Image (Captured.Status));
         elsif not Project_Tools.Text.Contains (To_String (Captured.Output), Needle) then
            Project_Tools.Release_Checks.Fail
              (Label & " output did not include " & Needle);
         end if;
      end Expect_Selector;
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

      Ada.Text_IO.Put_Line ("test selector smoke checks passed");
   end Run_Test_Selector_Smoke;

   procedure Run_Staged_Verification is
   begin
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Executable : constant String := Posix_Tools.Command_Inventory.Executable (I);
            Status     : constant String :=
              Posix_Tools.Host_Adapters.Executables.Verify_Identity_At_Path
                (Executable, Built_Command_Path (Executable));
         begin
            if Status /= "ok" then
               Project_Tools.Release_Checks.Fail
                 ("staged verification failed for " & Executable & ": " & Status);
            end if;
         end;
      end loop;

      Ada.Text_IO.Put_Line ("staged verification checks passed");
   end Run_Staged_Verification;

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
      else
         return "command:" & Name;
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
      Filter_Text : constant String := Test_Filter_Text;
   begin
      if Filter_Text /= "" then
         AUnit.Test_Filters.Set_Name (Name_Filter, Filter_Text);
         Options.Filter := Name_Filter'Unchecked_Access;
      else
         Options.Filter := null;
      end if;

      Runner (Reporter, Options);
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
      Generate_Release_Checksums;
      Run_Metadata_Checks;
      Run_Format_Checks;
      Run_Conformance_Checks;
      Run_Tests;
   elsif Command = "release" then
      Require_Clean_Source_Tree;
      Generate_Docs;
      Generate_Package_Manifest;
      Run_Build;
      Run_Test_Selector_Smoke;
      Run_Staged_Verification;
      Generate_Release_Checksums;
      Run_Metadata_Checks;
      Run_Format_Checks;
      Run_Conformance_Checks;
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
   elsif Command = "package" then
      Generate_Package_Manifest;
      Generate_Release_Checksums;
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
   when others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "posix_tools_tests: internal tooling failure");
      Ada.Command_Line.Set_Exit_Status (125);
end Posix_Tools_Tests;
