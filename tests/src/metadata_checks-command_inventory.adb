with Posix_Tools.Command_Inventory;
with Posix_Tools.Version;
with Project_Tools.Files;
with Tooling_Checks;
with Tooling_Support;

package body Metadata_Checks.Command_Inventory is
   use Tooling_Support;

   procedure Run is
      procedure Require_Command_Doc_Sections (Path : String) is
         procedure Require_Section (Heading : String) is
         begin
            Tooling_Checks.Require_Text
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
         if Executable = "explore" then
            return "tools/explore/src/library/explore-application.adb";
         elsif Executable = "false" then
            return "common/src/posix_tools-commands-false_command.adb";
         elsif Executable = "true" then
            return "common/src/posix_tools-commands-true_command.adb";
         else
            return "common/src/posix_tools-commands-" & Executable & ".adb";
         end if;
      end Command_Source_Path;
   begin
      Tooling_Checks.Require_Directory (Check, "docs/commands");
      Tooling_Checks.Require_File (Check, "docs/commands/index.md");
      Tooling_Checks.Require_File (Check, "docs/commands/basename.md");
      Tooling_Checks.Require_File (Check, "docs/commands/cat.md");
      Tooling_Checks.Require_File (Check, "docs/commands/dirname.md");
      Tooling_Checks.Require_File (Check, "docs/commands/echo.md");
      Tooling_Checks.Require_File (Check, "docs/commands/false.md");
      Tooling_Checks.Require_File (Check, "docs/commands/head.md");
      Tooling_Checks.Require_File (Check, "docs/commands/posix-tools.md");
      Tooling_Checks.Require_File (Check, "docs/commands/pwd.md");
      Tooling_Checks.Require_File (Check, "docs/commands/tail.md");
      Tooling_Checks.Require_File (Check, "docs/commands/true.md");
      Tooling_Checks.Require_File (Check, "docs/commands/wc.md");
      Require_Command_Doc_Sections ("docs/commands/posix-tools.md");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Require_Command_Doc_Sections (Posix_Tools.Command_Inventory.Documentation_Path (I));
         Tooling_Checks.Require_File
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I));
         Require_Crate_Metadata
           (Posix_Tools.Command_Inventory.Manifest_Path (I),
            Posix_Tools.Command_Inventory.Crate (I),
            "posix_tools_" & Posix_Tools.Command_Inventory.Executable (I) & ".gpr");
         Require_Synchronized_Version (Posix_Tools.Command_Inventory.Manifest_Path (I));
         Require_Exact_Line
           (Posix_Tools.Command_Inventory.Manifest_Path (I),
            "version = """ & Posix_Tools.Version.Version_String & """",
            Posix_Tools.Command_Inventory.Executable (I) & " manifest version");
         Tooling_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "[[depends-on]]");
         Tooling_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "posix_tools_common =");
         Tooling_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "posix_tools_common = ""*""");
         Tooling_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "[[pins]]");
         Tooling_Checks.Require_Text
           (Check,
            Posix_Tools.Command_Inventory.Manifest_Path (I),
            "posix_tools_common = { path = ""../../common"" }");
         Tooling_Checks.Require_Text
           (Check,
            Posix_Tools.Command_Inventory.Manifest_Path (I),
            "executables = [""" & Posix_Tools.Command_Inventory.Executable (I) & """]");
         Tooling_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "licenses = ""MIT""");
         Tooling_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "maintainers =");
         Tooling_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "[build-profiles]");
         Tooling_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), """*"" = ""development""");
         Forbid_Text
           (Posix_Tools.Command_Inventory.Manifest_Path (I),
            "aunit =",
            Posix_Tools.Command_Inventory.Executable (I) & " manifest must not depend on aunit");
         Forbid_Text
           (Posix_Tools.Command_Inventory.Manifest_Path (I),
            "project_tools =",
            Posix_Tools.Command_Inventory.Executable (I) & " manifest must not depend on project_tools");
         if Posix_Tools.Command_Inventory.Executable (I) /= "awk" then
            Forbid_Text
              (Posix_Tools.Command_Inventory.Manifest_Path (I),
               "hostkit =",
               Posix_Tools.Command_Inventory.Executable (I) & " manifest must not depend on hostkit");
         end if;
         if Posix_Tools.Command_Inventory.Executable (I) /= "awk"
           and then Posix_Tools.Command_Inventory.Executable (I) /= "grep"
           and then Posix_Tools.Command_Inventory.Executable (I) /= "sed"
         then
            Forbid_Text
              (Posix_Tools.Command_Inventory.Manifest_Path (I),
               "messages =",
               Posix_Tools.Command_Inventory.Executable (I) & " manifest must not depend on messages");
            Forbid_Text
              (Posix_Tools.Command_Inventory.Manifest_Path (I),
               "terminal_styles =",
               Posix_Tools.Command_Inventory.Executable (I)
               & " manifest must not depend on terminal_styles");
         end if;
         Forbid_Text
           ("tests/alire.toml",
            Posix_Tools.Command_Inventory.Crate (I) & " =",
            "tests manifest must not depend on command crate "
            & Posix_Tools.Command_Inventory.Crate (I));
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
         Tooling_Checks.Require_File
           (Check, Posix_Tools.Command_Inventory.Project_File_Path (I));
         Tooling_Checks.Require_Text
           (Check,
            Posix_Tools.Command_Inventory.Project_File_Path (I),
            "for Main use (""" & Posix_Tools.Command_Inventory.Main_Source (I) & """)");
         Tooling_Checks.Require_Text
           (Check,
            Posix_Tools.Command_Inventory.Project_File_Path (I),
            "for Object_Dir use ""obj/" & Posix_Tools.Command_Inventory.Executable (I) & """");
         Tooling_Checks.Require_Text
           (Check,
            Posix_Tools.Command_Inventory.Project_File_Path (I),
            "for Exec_Dir use ""bin""");
         Tooling_Checks.Require_File
           (Check,
            Posix_Tools.Command_Inventory.Wrapper_Path (I));
         declare
            Wrapper : constant String :=
              Posix_Tools.Command_Inventory.Wrapper_Path (I);
            Command_Source : constant String :=
              Command_Source_Path (Posix_Tools.Command_Inventory.Executable (I));
         begin
            if Posix_Tools.Command_Inventory.Executable (I) = "awk" then
               Tooling_Checks.Require_Text (Check, Wrapper, "Posix_Tools.Process_Entry");
               Tooling_Checks.Require_Text (Check, Wrapper, "Write_Identity");
               Tooling_Checks.Require_Text (Check, Wrapper, "Awk_CLI.Initialize_From_Process");
               Tooling_Checks.Require_Text (Check, Wrapper, "Awk_CLI.Run");
            elsif Posix_Tools.Command_Inventory.Executable (I) = "grep" then
               Tooling_Checks.Require_Text (Check, Wrapper, "Posix_Tools.Process_Entry");
               Tooling_Checks.Require_Text (Check, Wrapper, "Write_Identity");
               Tooling_Checks.Require_Text (Check, Wrapper, "Greplib.Patterns.Compile");
               Tooling_Checks.Require_Text (Check, Wrapper, "Greplib.Collected.Search_File");
               Tooling_Checks.Require_Text (Check, Wrapper, "Greplib.Collected.Search_Stream");
            elsif Posix_Tools.Command_Inventory.Executable (I) = "sed" then
               Tooling_Checks.Require_Text (Check, Wrapper, "Posix_Tools.Process_Entry");
               Tooling_Checks.Require_Text (Check, Wrapper, "Write_Identity");
               Tooling_Checks.Require_Text (Check, Wrapper, "Sed.Application.Run");
            else
               Tooling_Checks.Require_Text
                 (Check,
                  Wrapper,
                  "Posix_Tools.Host_Adapters.Run_Command");

               if Line_Count (Wrapper) > 20 then
                  Tooling_Checks.Fail
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
                 (Command_Source, "with Ada.Command_Line", Posix_Tools.Command_Inventory.Executable (I)
                  & " command must not read process command-line state directly");
               Forbid_Text
                 (Command_Source, "with Ada.Directories", Posix_Tools.Command_Inventory.Executable (I)
                  & " command must use project filesystem adapters");
               Forbid_Text
                 (Command_Source, "with Ada.Environment_Variables", Posix_Tools.Command_Inventory.Executable (I)
                  & " command must use project environment adapters");
               Forbid_Text
                 (Command_Source, "GNAT.OS_Lib", Posix_Tools.Command_Inventory.Executable (I)
                  & " command must use project host adapters for native services");
               Forbid_Text
                 (Command_Source, "with AUnit", Posix_Tools.Command_Inventory.Executable (I)
                  & " command must not depend on tests");
               Forbid_Text
                 (Command_Source, "with Project_Tools", Posix_Tools.Command_Inventory.Executable (I)
                  & " command must not depend on tooling");
            end if;
         end;
      end loop;
   end Run;
end Metadata_Checks.Command_Inventory;
