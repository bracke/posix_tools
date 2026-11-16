with Ada.Directories;
with Ada.Strings.Unbounded;
with Hostkit.Fs;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Text;
with Tooling_Checks;
with Tooling_Support;

package body Integration_Smoke.Catalogs is
   use Ada.Strings.Unbounded;

   function Prepare_Command
     (Name   : String;
      Layout : String) return String
   is
      Source : constant String := Tooling_Support.Built_Command_Path (Name);
      Bin    : constant String := Project_Tools.Files.Join (Layout, "bin");
      Target : constant String :=
        Project_Tools.Files.Join
          (Bin, Ada.Directories.Simple_Name (Source));
   begin
      Ada.Directories.Create_Path (Bin);
      Ada.Directories.Copy_File
        (Source_Name => Source,
         Target_Name => Target,
         Form        => "mode=overwrite,preserve=all_attributes");
      return Ada.Directories.Full_Name (Target);
   end Prepare_Command;

   function Invalid_Option
     (Label     : String;
      Program   : String;
      Layout    : String;
      Search_In : String) return Project_Tools.Processes.Captured_Process
   is
   begin
      return Tooling_Support.Capture_Within
        (Label,
         Tooling_Support.Built_Command_Path ("env"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("-i"),
             Project_Tools.Processes.Argument ("PATH=" & Search_In),
             Project_Tools.Processes.Argument ("LC_ALL=da"),
             Project_Tools.Processes.Argument ("LANG=da"),
             Project_Tools.Processes.Argument (Program),
             Project_Tools.Processes.Argument ("--definitely-invalid")]),
         Err_To_Out          => True,
         Working_Directory   => Ada.Directories.Full_Name (Layout));
   end Invalid_Option;

   procedure Require_Text
     (Output : String;
      Text   : String;
      Label  : String) is
   begin
      if not Project_Tools.Text.Contains (Output, Text) then
         Tooling_Checks.Fail
           (Label & " did not contain """ & Text & """: "
            & Tooling_Support.Display_Output (Output));
      end if;
   end Require_Text;

   procedure Forbid_Text
     (Output : String;
      Text   : String;
      Label  : String) is
   begin
      if Project_Tools.Text.Contains (Output, Text) then
         Tooling_Checks.Fail
           (Label & " exposed message key " & Text & ": "
            & Tooling_Support.Display_Output (Output));
      end if;
   end Forbid_Text;

   procedure Run is
      Work : constant String :=
        Hostkit.Fs.Create_Temporary_Directory
          ("posix-tools-catalog-regressions");

      procedure Check_Sed_Missing is
         Layout   : constant String :=
           Project_Tools.Files.Join (Work, "sed-missing");
         Program  : constant String := Prepare_Command ("sed", Layout);
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Invalid_Option
             ("sed missing catalog fallback",
              Program,
              Layout,
              Project_Tools.Files.Join (Layout, "bin"));
         Output   : constant String := To_String (Captured.Output);
      begin
         if Captured.Status /= 2 then
            Tooling_Checks.Fail
              ("sed missing-catalog diagnostic returned status"
               & Integer'Image (Captured.Status));
         end if;
         Require_Text
           (Output, "unrecognized option", "sed missing catalog fallback");
         Require_Text
           (Output,
            "try '--help' for more information",
            "sed missing catalog fallback");
         Forbid_Text
           (Output,
            "sed.error.option.unknown",
            "sed missing catalog fallback");
         Forbid_Text
           (Output, "sed.hint.try_help", "sed missing catalog fallback");
      end Check_Sed_Missing;

      procedure Check_Sed_Found_Through_Path is
         Layout       : constant String :=
           Project_Tools.Files.Join (Work, "sed-found");
         Program      : constant String := Prepare_Command ("sed", Layout);
         pragma Unreferenced (Program);
         Catalog_Dir  : constant String :=
           Project_Tools.Files.Join (Layout, "share/sed/messages");
         Catalog_Path : constant String :=
           Project_Tools.Files.Join (Catalog_Dir, "catalog.txt");
         Captured     : Project_Tools.Processes.Captured_Process;
      begin
         Ada.Directories.Create_Path (Catalog_Dir);
         Project_Tools.Files.Copy_File
           (Project_Tools.Files.Join
              (Tooling_Support.Root,
               "tools/sed/share/sed/messages/catalog.txt"),
            Catalog_Path);
         Captured :=
           Invalid_Option
             ("sed PATH catalog lookup",
              "sed",
              Layout,
              Project_Tools.Files.Join (Layout, "bin"));
         if Captured.Status /= 2 then
            Tooling_Checks.Fail
              ("sed PATH catalog lookup returned status"
               & Integer'Image (Captured.Status));
         end if;
         Require_Text
           (To_String (Captured.Output),
            "ukendt tilvalg",
            "sed PATH catalog lookup");
         Forbid_Text
           (To_String (Captured.Output),
            "sed.error.option.unknown",
            "sed PATH catalog lookup");
      end Check_Sed_Found_Through_Path;

      procedure Check_Awk_Missing is
         Layout   : constant String :=
           Project_Tools.Files.Join (Work, "awk-missing");
         Program  : constant String := Prepare_Command ("awk", Layout);
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Invalid_Option
             ("awk missing catalog fallback",
              Program,
              Layout,
              Project_Tools.Files.Join (Layout, "bin"));
         Output   : constant String := To_String (Captured.Output);
      begin
         if Captured.Status /= 2 then
            Tooling_Checks.Fail
              ("awk missing-catalog diagnostic returned status"
               & Integer'Image (Captured.Status));
         end if;
         Require_Text
           (Output, "unknown option", "awk missing catalog fallback");
         Require_Text
           (Output,
            "use --help for command-line syntax",
            "awk missing catalog fallback");
         Forbid_Text
           (Output,
            "awk.usage.unknown_option",
            "awk missing catalog fallback");
         Forbid_Text
           (Output, "awk.hint.use_help", "awk missing catalog fallback");
      end Check_Awk_Missing;
   begin
      if Work = "" then
         Tooling_Checks.Fail
           ("could not create temporary directory for catalog integration tests");
      end if;
      begin
         Check_Sed_Missing;
         Check_Sed_Found_Through_Path;
         Check_Awk_Missing;
         Project_Tools.Files.Delete_Tree (Work);
      exception
         when others =>
            Tooling_Support.Best_Effort_Delete_Tree (Work);
            raise;
      end;
   end Run;
end Integration_Smoke.Catalogs;
