with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Text.Matching;
with Posix_Tools.Version;
with Project_Tools.Files;
with Project_Tools.Release_Checks;
with Project_Tools.Text;
with Tooling_Support;

package body Metadata_Checks.Manifests is
   use Tooling_Support;

   procedure Run is
      Root_Manifest : constant String :=
        Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "alire.toml"));

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
      begin
         return Command_Manpage (Index);
      end Expected_Manpage;

      function Expected_Root_Manpage return String is
      begin
         return Root_Manpage;
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

      function Expected_Command_Reference_Index return String is
         use Ada.Strings.Unbounded;
         Content : Unbounded_String;
         Root_Inserted : Boolean := False;
      begin
         Append (Content, "# Command References" & Character'Val (10) & Character'Val (10));
         Append (Content, "V1 command references:" & Character'Val (10) & Character'Val (10));

         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            if not Root_Inserted
              and then "posix-tools" < Posix_Tools.Command_Inventory.Executable (I)
            then
               Append (Content, "- [posix-tools](posix-tools.md)" & Character'Val (10));
               Root_Inserted := True;
            end if;

            Append
              (Content,
               "- [" & Posix_Tools.Command_Inventory.Executable (I) & "]("
               & Posix_Tools.Command_Inventory.Executable (I) & ".md)"
               & Character'Val (10));
         end loop;

         if not Root_Inserted then
            Append (Content, "- [posix-tools](posix-tools.md)" & Character'Val (10));
         end if;

         return To_String (Content);
      end Expected_Command_Reference_Index;

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
           ("docs/commands/index.md",
            Expected_Command_Reference_Index,
            "command reference index is stale");
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

      --  A usage diagnostic is a catalog message named by a Usage_Message;
      --  a string literal handed to Usage_Error as the message would be
      --  English text the catalog never sees, and its operand would reach the
      --  terminal unescaped.
      procedure Check_No_Literal_Usage_Messages is
         use Ada.Strings.Unbounded;
         Call_Token : constant String := "Usage_" & "Error";
         Source_Roots : constant Project_Tools.Files.Name_List :=
           [To_Unbounded_String ("common/src"),
            To_Unbounded_String ("src"),
            To_Unbounded_String ("tools")];

         procedure Check_File (File_Path : String);

         --  The message argument, the third, of the call whose argument list
         --  opens at Open in Text, or "" when the call has fewer arguments.
         function Message_Argument (Text : String; Open : Positive) return String;

         procedure Check_File (File_Path : String) is
            Text : constant String := Project_Tools.Files.Read_Raw_File (File_Path);
            From : Positive := Text'First;
         begin
            loop
               declare
                  At_Call : constant Natural := Ada.Strings.Fixed.Index (Text (From .. Text'Last), Call_Token);
                  Open    : Natural;
               begin
                  exit when At_Call = 0;
                  Open := At_Call + Call_Token'Length;
                  while Open <= Text'Last and then Text (Open) in ' ' | ASCII.LF | ASCII.CR loop
                     Open := Open + 1;
                  end loop;
                  exit when Open > Text'Last;
                  if Text (Open) = '(' then
                     declare
                        Message : constant String := Message_Argument (Text, Open);
                     begin
                        if Ada.Strings.Fixed.Index (Message, """") /= 0 then
                           Project_Tools.Release_Checks.Fail
                             ("usage diagnostic message must be a catalog Usage_Message, not a string literal, in "
                              & File_Path & ": " & Message);
                        end if;
                     end;
                  end if;
                  From := Open;
               end;
            end loop;
         end Check_File;

         function Message_Argument (Text : String; Open : Positive) return String is
            Depth     : Natural := 0;
            Commas    : Natural := 0;
            In_String : Boolean := False;
            First     : Natural := 0;
         begin
            for I in Open .. Text'Last loop
               if Text (I) = '"' then
                  In_String := not In_String;
               elsif In_String then
                  null;
               elsif Text (I) = '(' then
                  Depth := Depth + 1;
               elsif Depth = 1 and then Text (I) in ')' | ',' then
                  if Commas = 2 then
                     return Ada.Strings.Fixed.Trim (Text (First .. I - 1), Ada.Strings.Both);
                  end if;
                  exit when Text (I) = ')';
                  Commas := Commas + 1;
                  First := I + 1;
               elsif Text (I) = ')' then
                  Depth := Depth - 1;
               end if;
            end loop;
            return "";
         end Message_Argument;
      begin
         for Source_Root of Source_Roots loop
            for Path of Project_Tools.Files.List_Tree (Project_Tools.Files.Join (Root, To_String (Source_Root))) loop
               declare
                  File_Path : constant String := To_String (Path);
               begin
                  if Project_Tools.Text.Ends_With (File_Path, ".adb")
                    or else Project_Tools.Text.Ends_With (File_Path, ".ads")
                  then
                     Check_File (File_Path);
                  end if;
               end;
            end loop;
         end loop;
      end Check_No_Literal_Usage_Messages;

      --  Every usage diagnostic has its text in each catalog locale, and the
      --  English text it falls back to is the catalog's own.
      procedure Require_Usage_Messages_Catalogued is
         package Messages renames Posix_Tools.Commands.Usage_Messages;
         Catalog : constant String :=
           Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "common/messages/posix_tools.catalog"));

         --  Text with each single quote doubled, as the catalog writes it.
         function Catalog_Text (Text : String) return String;
         procedure Require_Translation (Message : Messages.Usage_Message; Locale : String);

         function Catalog_Text (Text : String) return String is
         begin
            for I in Text'Range loop
               if Text (I) = ''' then
                  return Text (Text'First .. I) & "'" & Catalog_Text (Text (I + 1 .. Text'Last));
               end if;
            end loop;
            return Text;
         end Catalog_Text;

         procedure Require_Translation (Message : Messages.Usage_Message; Locale : String) is
         begin
            if not Posix_Tools.Text.Matching.Contains (Catalog, ASCII.LF & Locale & "." & Messages.Key (Message) & " = ")
            then
               Project_Tools.Release_Checks.Fail
                 ("usage diagnostic " & Messages.Key (Message) & " has no " & Locale & " catalog text");
            end if;
         end Require_Translation;
      begin
         for Message in Messages.Usage_Message loop
            Require_Translation (Message, "da");
            Require_Translation (Message, "es");
            if not Posix_Tools.Text.Matching.Contains
              (Catalog,
               ASCII.LF & "en." & Messages.Key (Message) & " = " & Catalog_Text (Messages.Default (Message)) & ASCII.LF)
            then
               Project_Tools.Release_Checks.Fail
                 ("usage diagnostic " & Messages.Key (Message) & " default differs from its en catalog text");
            end if;
         end loop;
      end Require_Usage_Messages_Catalogued;
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
      Require_Crate_Metadata ("alire.toml", "posix_tools", "posix_tools.gpr");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Forbid_Text
           ("alire.toml",
            Posix_Tools.Command_Inventory.Crate (I) & " =",
            "root manifest must not depend on command crate "
            & Posix_Tools.Command_Inventory.Crate (I));
      end loop;
      Project_Tools.Release_Checks.Require_File (Check, "alire.toml");
      Project_Tools.Release_Checks.Require_File (Check, ".gitattributes");
      Project_Tools.Release_Checks.Require_File (Check, "posix_tools.gpr");
      Project_Tools.Release_Checks.Require_Text (Check, "posix_tools.gpr", "for Object_Dir use ""obj/root""");
      Project_Tools.Release_Checks.Require_Text (Check, "posix_tools.gpr", "for Exec_Dir use ""bin""");
      Project_Tools.Release_Checks.Require_File (Check, "common/alire.toml");
      Project_Tools.Release_Checks.Require_File (Check, "common/posix_tools_common.gpr");
      Project_Tools.Release_Checks.Require_Text (Check, "common/alire.toml", "i18n = ""*""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/alire.toml", "i18n = { path = ""../../i18n"" }");
      Project_Tools.Release_Checks.Require_Text (Check, "common/posix_tools_common.gpr", "../../i18n/i18n.gpr");
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
      Project_Tools.Release_Checks.Require_File (Check, "common/src/posix_tools-tail_rings.ads");
      Project_Tools.Release_Checks.Require_File (Check, "common/src/posix_tools-wc_fields.ads");
      Project_Tools.Release_Checks.Require_Text (Check, "SECURITY.md", "untrusted input");
      Project_Tools.Release_Checks.Require_Text (Check, "SECURITY.md", "elevated privileges");
      Project_Tools.Release_Checks.Require_Text (Check, "SECURITY.md", "temporary-storage");
      Project_Tools.Release_Checks.Require_Text (Check, "SECURITY.md", "bounded executable identity verification");
      Project_Tools.Release_Checks.Require_Text (Check, "SECURITY.md", "archive integrity");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "DOCS-SECURITY-CURRENT-001");
      Project_Tools.Release_Checks.Require_Text (Check, "CHANGELOG.md", "31 POSIX-style utilities");
      Project_Tools.Release_Checks.Require_Text (Check, "CHANGELOG.md", "`awk`, `grep`, and `sed`");
      Project_Tools.Release_Checks.Require_Text (Check, "CHANGELOG.md", "messages-backed locale support");
      Project_Tools.Release_Checks.Require_Text (Check, "CHANGELOG.md", "host adapter boundaries");
      Project_Tools.Release_Checks.Require_Text (Check, "CHANGELOG.md", "archive integrity");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "DOCS-CHANGELOG-CURRENT-001");
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
      Project_Tools.Release_Checks.Require_File (Check, "generated/package-files.txt");
      Project_Tools.Release_Checks.Require_File (Check, "generated/package-manifest.txt");
      Project_Tools.Release_Checks.Require_File (Check, "generated/release-checksums.txt");
      Project_Tools.Release_Checks.Require_File (Check, "generated/requirements.csv");
      Project_Tools.Release_Checks.Require_File (Check, "generated/regressions.csv");
      Project_Tools.Release_Checks.Require_File (Check, ".github/workflows/ci.yml");
      Check_Ada_Only_Tooling;
      Check_No_Silent_Broad_Handlers;
      Check_No_Literal_Usage_Messages;
      Require_Usage_Messages_Catalogued;
   end Run;
end Metadata_Checks.Manifests;
