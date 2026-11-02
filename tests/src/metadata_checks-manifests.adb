with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Text.Matching;
with Project_Tools.Files;
with Tooling_Checks;
with Project_Tools.Text;
with Tooling_Support;

package body Metadata_Checks.Manifests is
   use Tooling_Support;

   procedure Run is
      Root_Manifest : constant String :=
        Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "alire.toml"));

      procedure Require_Command_Inventory_Current is
         Path     : constant String := "generated/command_inventory.csv";
         Actual   : constant String := Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));
         Expected : constant String := Command_Inventory_Csv;
      begin
         if Actual /= Expected then
            Tooling_Checks.Fail ("generated command inventory is stale");
         end if;
      end Require_Command_Inventory_Current;

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
            Tooling_Checks.Fail (Message);
         end if;
      end Require_File_Equals;

      procedure Require_Generated_Docs_Current is
      begin
         Require_File_Equals
           ("docs/commands/index.md",
            Command_Reference_Index,
            "command reference index is stale");
         Require_File_Equals
           ("generated/manual-index.md",
            Manual_Index,
            "generated manual index is stale");
         Require_File_Equals
           ("generated/man/posix-tools.1",
            Root_Manpage,
            "generated root manual page is stale");

         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            declare
               Command : constant String := Posix_Tools.Command_Inventory.Executable (I);
            begin
               Require_File_Equals
                 ("generated/man/" & Command & ".1",
                  Command_Manpage (I),
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

      --  generated/man holds a page for each inventory command and the root
      --  page, and nothing else: a page for a command that has left the
      --  inventory would otherwise ship unnoticed.
      procedure Require_No_Stray_Manpages is
         Pages : constant Project_Tools.Files.Path_List :=
           Project_Tools.Files.List_Tree (Project_Tools.Files.Join (Root, "generated/man"));
      begin
         for Page of Pages loop
            declare
               Name : constant String := Simple_Name (Ada.Strings.Unbounded.To_String (Page));
               Stem : constant String :=
                 (if Name'Length > 2 and then Name (Name'Last - 1 .. Name'Last) = ".1"
                  then Name (Name'First .. Name'Last - 2)
                  else "");
            begin
               if Stem /= "posix-tools"
                 and then not Posix_Tools.Command_Inventory.Contains_Executable (Stem)
               then
                  Tooling_Checks.Fail
                    ("generated/man/" & Name & " is not the manual page of an inventory command");
               end if;
            end;
         end loop;
      end Require_No_Stray_Manpages;

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
                 To_Unbounded_String ("test-work"),
                 To_Unbounded_String ("lib"),
                 To_Unbounded_String ("obj")]);
      begin
         for Path of Files loop
            declare
               File_Path : constant String := To_String (Path);
            begin
               if Has_Prohibited_Tooling_Name (File_Path) then
                  Tooling_Checks.Fail
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
                     Tooling_Checks.Fail
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
                           Tooling_Checks.Fail
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
               Tooling_Checks.Fail
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
               Tooling_Checks.Fail
                 ("usage diagnostic " & Messages.Key (Message) & " default differs from its en catalog text");
            end if;
         end loop;
      end Require_Usage_Messages_Catalogued;

      --  Every message key the common sources name as a whole literal,
      --  "posix_tools." and the rest, has its text in each catalog locale:
      --  a key the catalog lacks shows its English default in every locale.
      --  A literal that ends in "." is the prefix of keys composed at run
      --  time, not a key.
      procedure Require_Message_Keys_Catalogued is
         Catalog : constant String :=
           Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "common/messages/posix_tools.catalog"));
         Key_Start : constant String := """posix_tools.";

         procedure Check_File (File_Path : String);
         procedure Require_Text (Key : String; Locale : String; File_Path : String);

         procedure Check_File (File_Path : String) is
            Text : constant String := Project_Tools.Files.Read_Raw_File (File_Path);
            From : Positive := Text'First;
         begin
            loop
               declare
                  At_Key : constant Natural := Ada.Strings.Fixed.Index (Text (From .. Text'Last), Key_Start);
                  Last   : Natural;
               begin
                  exit when At_Key = 0;
                  Last := At_Key + 1;
                  while Last < Text'Last and then Text (Last + 1) in 'a' .. 'z' | '0' .. '9' | '_' | '.' loop
                     Last := Last + 1;
                  end loop;
                  if Last < Text'Last and then Text (Last + 1) = '"' and then Text (Last) /= '.' then
                     Require_Text (Text (At_Key + 1 .. Last), "en", File_Path);
                     Require_Text (Text (At_Key + 1 .. Last), "da", File_Path);
                     Require_Text (Text (At_Key + 1 .. Last), "es", File_Path);
                  end if;
                  exit when Last >= Text'Last;
                  From := Last + 1;
               end;
            end loop;
         end Check_File;

         procedure Require_Text (Key : String; Locale : String; File_Path : String) is
         begin
            if not Posix_Tools.Text.Matching.Contains (Catalog, ASCII.LF & Locale & "." & Key & " = ") then
               Tooling_Checks.Fail
                 ("message key " & Key & " used in " & File_Path & " has no " & Locale & " catalog text");
            end if;
         end Require_Text;
      begin
         for Path of Project_Tools.Files.List_Tree (Project_Tools.Files.Join (Root, "common/src")) loop
            declare
               File_Path : constant String := Ada.Strings.Unbounded.To_String (Path);
            begin
               if Project_Tools.Text.Ends_With (File_Path, ".adb")
                 or else Project_Tools.Text.Ends_With (File_Path, ".ads")
               then
                  Check_File (File_Path);
               end if;
            end;
         end loop;
      end Require_Message_Keys_Catalogued;
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
         Tooling_Checks.Fail ("root manifest has prohibited direct external dependency");
      end if;

      if Root_Manifest = "" then
         Tooling_Checks.Fail ("root manifest could not be read");
      end if;

      Tooling_Checks.Require_Text (Check, "alire.toml", "executables = [""posix-tools""]");
      Tooling_Checks.Require_Text (Check, "posix_tools.gpr", "for Main use (""posix-tools.adb"")");
      Tooling_Checks.Require_Text
        (Check, "alire.toml", "posix_tools_common = { path = ""common"" }");
      Require_Crate_Metadata ("alire.toml", "posix_tools", "posix_tools.gpr");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Forbid_Text
           ("alire.toml",
            Posix_Tools.Command_Inventory.Crate (I) & " =",
            "root manifest must not depend on command crate "
            & Posix_Tools.Command_Inventory.Crate (I));
      end loop;
      Tooling_Checks.Require_File (Check, "alire.toml");
      Tooling_Checks.Require_File (Check, ".gitattributes");
      Tooling_Checks.Require_File (Check, "posix_tools.gpr");
      Tooling_Checks.Require_Text (Check, "posix_tools.gpr", "for Object_Dir use ""obj/root""");
      Tooling_Checks.Require_Text (Check, "posix_tools.gpr", "for Exec_Dir use ""bin""");
      Tooling_Checks.Require_File (Check, "common/alire.toml");
      Tooling_Checks.Require_File (Check, "common/posix_tools_common.gpr");
      Tooling_Checks.Require_Text (Check, "common/alire.toml", "i18n = ""*""");
      Tooling_Checks.Require_Text
        (Check, "common/alire.toml", "i18n = { path = ""../../i18n"" }");
      Tooling_Checks.Require_Text (Check, "common/posix_tools_common.gpr", "../../i18n/i18n.gpr");
      Tooling_Checks.Require_Text
        (Check, "common/posix_tools_common.gpr", "for Object_Dir use ""obj/common""");
      Tooling_Checks.Require_Text
        (Check, "common/posix_tools_common.gpr", "for Library_Dir use ""lib""");
      Tooling_Checks.Require_File (Check, "common/messages/posix_tools.catalog");
      Tooling_Checks.Require_File (Check, "common/src/posix_tools-localization.ads");
      Tooling_Checks.Require_File (Check, "common/src/posix_tools-presentation.ads");
      Tooling_Checks.Require_File (Check, "common/src/posix_tools-host_adapters-terminals.ads");
      Tooling_Checks.Require_File (Check, "common/src/posix_tools-text.ads");
      Tooling_Checks.Require_File (Check, "common/src/posix_tools-text-classification.ads");
      Tooling_Checks.Require_File (Check, "common/src/posix_tools-text-utf_8.ads");
      Tooling_Checks.Require_File (Check, "common/src/posix_tools-tail_rings.ads");
      Tooling_Checks.Require_File (Check, "common/src/posix_tools-wc_fields.ads");
      Tooling_Checks.Require_Text (Check, "SECURITY.md", "untrusted input");
      Tooling_Checks.Require_Text (Check, "SECURITY.md", "elevated privileges");
      Tooling_Checks.Require_Text (Check, "SECURITY.md", "temporary-storage");
      Tooling_Checks.Require_Text (Check, "SECURITY.md", "bounded executable identity verification");
      Tooling_Checks.Require_Text (Check, "SECURITY.md", "archive integrity");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "DOCS-SECURITY-CURRENT-001");
      Tooling_Checks.Require_Text (Check, "CHANGELOG.md", "31 POSIX-style utilities");
      Tooling_Checks.Require_Text (Check, "CHANGELOG.md", "`awk`, `grep`, and `sed`");
      Tooling_Checks.Require_Text (Check, "CHANGELOG.md", "messages-backed locale support");
      Tooling_Checks.Require_Text (Check, "CHANGELOG.md", "host adapter boundaries");
      Tooling_Checks.Require_Text (Check, "CHANGELOG.md", "archive integrity");
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "DOCS-CHANGELOG-CURRENT-001");
      Tooling_Checks.Require_File (Check, "tests/alire.toml");
      Tooling_Checks.Require_File (Check, "tests/posix_tools_tests.gpr");
      Tooling_Checks.Require_Text
        (Check, "tests/posix_tools_tests.gpr", "for Object_Dir use ""obj/tests""");
      Tooling_Checks.Require_Text
        (Check, "tests/posix_tools_tests.gpr", "for Exec_Dir use ""bin""");
      Tooling_Checks.Require_File (Check, "generated/command_inventory.csv");
      Require_Command_Inventory_Current;
      Tooling_Checks.Require_File (Check, "generated/manual-index.md");
      Tooling_Checks.Require_File (Check, "generated/man/posix-tools.1");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Tooling_Checks.Require_File
           (Check, "generated/man/" & Posix_Tools.Command_Inventory.Executable (I) & ".1");
      end loop;
      Require_Generated_Docs_Current;
      Require_No_Stray_Manpages;
      Tooling_Checks.Require_File (Check, "generated/package-files.txt");
      Tooling_Checks.Require_File (Check, "generated/package-manifest.txt");
      Tooling_Checks.Require_File (Check, "generated/release-checksums.txt");
      Tooling_Checks.Require_File (Check, "generated/requirements.csv");
      Tooling_Checks.Require_File (Check, "generated/regressions.csv");
      Tooling_Checks.Require_File (Check, ".github/workflows/ci.yml");
      Check_Ada_Only_Tooling;
      Check_No_Silent_Broad_Handlers;
      Check_No_Literal_Usage_Messages;
      Require_Usage_Messages_Catalogued;
      Require_Message_Keys_Catalogued;
   end Run;
end Metadata_Checks.Manifests;
