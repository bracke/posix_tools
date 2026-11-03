with Ada.Characters.Handling;
with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Text.Matching;
with Project_Tools.Ada_Source;
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

      --  Every "en." message of the catalog at Catalog_Path has its English
      --  text, the same, in the defaults table at Defaults_Path, which the
      --  command shows when it cannot read the catalog: never a message key.
      procedure Require_Catalog_Defaults (Catalog_Path, Defaults_Path : String) is
         use Ada.Strings.Unbounded;
         LF       : constant Character := ASCII.LF;
         Quote    : constant Character := Character'Val (39);
         Catalog  : constant String :=
           Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Catalog_Path));
         Raw      : constant String :=
           Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Defaults_Path));
         Split    : constant String := """ &" & LF & "           """;
         Defaults : Unbounded_String;
         From     : Positive := Raw'First;
         Start    : Positive := Catalog'First;

         --  Check the catalog line Line.
         procedure Check_Line (Line : String);

         --  Text as an Ada string literal's contents.
         function Quoted (Text : String) return String;

         procedure Check_Line (Line : String) is
            Separator : constant Natural := Ada.Strings.Fixed.Index (Line, " = ");
         begin
            if Line'Length > 3 and then Line (Line'First .. Line'First + 2) = "en." and then Separator > 0 then
               declare
                  Key   : constant String := Line (Line'First + 3 .. Separator - 1);
                  Text  : constant String := Line (Separator + 3 .. Line'Last);
                  Plain : Unbounded_String;
                  I     : Natural := Text'First;
               begin
                  while I <= Text'Last loop
                     Append (Plain, Text (I));
                     if Text (I) = Quote and then I < Text'Last and then Text (I + 1) = Quote then
                        I := I + 1;
                     end if;
                     I := I + 1;
                  end loop;
                  if not Posix_Tools.Text.Matching.Contains
                    (To_String (Defaults),
                     "Key = """ & Key & """ then" & LF & "         return" & LF & "           """
                     & Quoted (To_String (Plain)) & """;")
                  then
                     Tooling_Checks.Fail
                       ("message " & Key & " of " & Catalog_Path & " has no matching English default in "
                        & Defaults_Path);
                  end if;
               end;
            end if;
         end Check_Line;

         function Quoted (Text : String) return String is
            Result : Unbounded_String;
         begin
            for Ch of Text loop
               Append (Result, Ch);
               if Ch = '"' then
                  Append (Result, Ch);
               end if;
            end loop;
            return To_String (Result);
         end Quoted;
      begin
         loop
            declare
               At_Split : constant Natural := Ada.Strings.Fixed.Index (Raw (From .. Raw'Last), Split);
            begin
               if At_Split = 0 then
                  Append (Defaults, Raw (From .. Raw'Last));
                  exit;
               end if;
               Append (Defaults, Raw (From .. At_Split - 1));
               From := At_Split + Split'Length;
            end;
         end loop;

         for I in Catalog'Range loop
            if Catalog (I) = LF then
               Check_Line (Catalog (Start .. I - 1));
               Start := I + 1;
            end if;
         end loop;
      end Require_Catalog_Defaults;

      procedure Check_No_Silent_Broad_Handlers is
         use Ada.Strings.Unbounded;
         Source_Roots : constant Project_Tools.Files.Name_List :=
           [To_Unbounded_String ("common/src"),
            To_Unbounded_String ("src"),
            To_Unbounded_String ("tests/src"),
            To_Unbounded_String ("tools")];

         function Line_Start
           (Content     : String;
            Line_Number : Positive) return Natural
         is
            Current : Positive := 1;
         begin
            if Line_Number = 1 then
               return Content'First;
            end if;

            for Index in Content'Range loop
               if Content (Index) = Character'Val (10) then
                  Current := Current + 1;
                  if Current = Line_Number then
                     return Index + 1;
                  end if;
               end if;
            end loop;
            return 0;
         end Line_Start;

         type Silent_Handler_Info is record
            Is_Silent   : Boolean := False;
            Intentional : Boolean := False;
         end record;

         Barrier_Marker : constant String :=
           "intentional terminal exception barrier";

         function Inspect_Silent_Handler
           (Content     : String;
            Line_Number : Positive) return Silent_Handler_Info
         is
            Cursor : Natural := Line_Start (Content, Line_Number);
            Result : Silent_Handler_Info;

            procedure Skip_Trivia is
            begin
               loop
                  while Cursor <= Content'Last
                    and then Content (Cursor) in ' ' | Character'Val (9)
                      | Character'Val (10) | Character'Val (13)
                  loop
                     Cursor := Cursor + 1;
                  end loop;

                  exit when Cursor >= Content'Last
                    or else Content (Cursor .. Cursor + 1) /= "--";

                  declare
                     First : constant Natural := Cursor;
                  begin
                     while Cursor <= Content'Last
                       and then Content (Cursor) /= Character'Val (10)
                     loop
                        Cursor := Cursor + 1;
                     end loop;
                     if Ada.Strings.Fixed.Index
                       (Ada.Characters.Handling.To_Lower
                          (Content (First .. Cursor - 1)),
                        Barrier_Marker) > 0
                     then
                        Result.Intentional := True;
                     end if;
                  end;
               end loop;
            end Skip_Trivia;

            function At_Keyword (Keyword : String) return Boolean is
               After : constant Natural := Cursor + Keyword'Length;
            begin
               return Cursor <= Content'Last
                 and then Keyword'Length <= Content'Last - Cursor + 1
                 and then Ada.Characters.Handling.To_Lower
                   (Content (Cursor .. After - 1)) = Keyword
                 and then
                   (After > Content'Last
                    or else not Project_Tools.Ada_Source.Is_Identifier_Character
                      (Content (After)));
            end At_Keyword;

            procedure Skip_Pragma is
               In_Pragma_String : Boolean := False;
            begin
               while Cursor <= Content'Last loop
                  if Content (Cursor) = '"' then
                     if In_Pragma_String
                       and then Cursor < Content'Last
                       and then Content (Cursor + 1) = '"'
                     then
                        Cursor := Cursor + 2;
                     else
                        In_Pragma_String := not In_Pragma_String;
                        Cursor := Cursor + 1;
                     end if;
                  elsif not In_Pragma_String and then Content (Cursor) = ';' then
                     Cursor := Cursor + 1;
                     return;
                  else
                     Cursor := Cursor + 1;
                  end if;
               end loop;
            end Skip_Pragma;

            procedure Skip_Label is
            begin
               Cursor := Cursor + 2;
               while Cursor < Content'Last
                 and then Content (Cursor .. Cursor + 1) /= ">>"
               loop
                  Cursor := Cursor + 1;
               end loop;
               if Cursor < Content'Last then
                  Cursor := Cursor + 2;
               end if;
            end Skip_Label;

            In_String    : Boolean := False;
            Begin_Depth  : Natural := 0;
         begin
            if Cursor = 0 then
               return Result;
            end if;

            --  Find the handler arrow as Ada code, ignoring arrows in
            --  comments and string literals on a continued choice line.
            while Cursor < Content'Last loop
               if not In_String
                 and then Content (Cursor .. Cursor + 1) = "--"
               then
                  while Cursor <= Content'Last
                    and then Content (Cursor) /= Character'Val (10)
                  loop
                     Cursor := Cursor + 1;
                  end loop;
               elsif Content (Cursor) = '"' then
                  if In_String
                    and then Cursor < Content'Last
                    and then Content (Cursor + 1) = '"'
                  then
                     Cursor := Cursor + 2;
                  else
                     In_String := not In_String;
                     Cursor := Cursor + 1;
                  end if;
               elsif not In_String
                 and then Content (Cursor .. Cursor + 1) = "=>"
               then
                  exit;
               else
                  Cursor := Cursor + 1;
               end if;
            end loop;
            if Cursor >= Content'Last then
               return Result;
            end if;
            Cursor := Cursor + 2;
            Skip_Trivia;

            --  Ignore structural wrappers around the handler's first
            --  effective statement. Labels and declarative pragmas must not
            --  turn a swallowed exception into an apparent action.
            loop
               if At_Keyword ("begin") then
                  Begin_Depth := Begin_Depth + 1;
                  Cursor := Cursor + 5;
                  Skip_Trivia;
               elsif Cursor < Content'Last
                 and then Content (Cursor .. Cursor + 1) = "<<"
               then
                  Skip_Label;
                  Skip_Trivia;
               elsif At_Keyword ("pragma") then
                  Skip_Pragma;
                  Skip_Trivia;
               else
                  exit;
               end if;
            end loop;

            declare
               Keyword_Length : Natural := 0;
            begin
               if Cursor + 3 <= Content'Last
                 and then Ada.Characters.Handling.To_Lower
                   (Content (Cursor .. Cursor + 3)) = "null"
                 and then
                   (Cursor + 4 > Content'Last
                    or else not Project_Tools.Ada_Source.Is_Identifier_Character
                      (Content (Cursor + 4)))
               then
                  Keyword_Length := 4;
               elsif Cursor + 5 <= Content'Last
                 and then Ada.Characters.Handling.To_Lower
                   (Content (Cursor .. Cursor + 5)) = "return"
                 and then
                   (Cursor + 6 > Content'Last
                    or else not Project_Tools.Ada_Source.Is_Identifier_Character
                      (Content (Cursor + 6)))
               then
                  Keyword_Length := 6;
               else
                  return Result;
               end if;
               Cursor := Cursor + Keyword_Length;
            end;
            Skip_Trivia;
            if Cursor > Content'Last or else Content (Cursor) /= ';' then
               return Result;
            end if;
            Cursor := Cursor + 1;
            Skip_Trivia;

            while Begin_Depth > 0 loop
               if not At_Keyword ("end") then
                  return Result;
               end if;
               Cursor := Cursor + 3;
               Skip_Trivia;
               if Cursor > Content'Last or else Content (Cursor) /= ';' then
                  return Result;
               end if;
               Cursor := Cursor + 1;
               Begin_Depth := Begin_Depth - 1;
               Skip_Trivia;
            end loop;

            --  A null before another handler statement is not a silent
            --  handler. At EOF, "when", or the handled sequence's "end",
            --  the swallowed exception has no remaining action.
            Result.Is_Silent :=
              Cursor > Content'Last
              or else At_Keyword ("when")
              or else At_Keyword ("end");
            return Result;
         end Inspect_Silent_Handler;
      begin
         declare
            LF : constant Character := Character'Val (10);
            Split_Null : constant Silent_Handler_Info :=
              Inspect_Silent_Handler
                ("when others -- misleading =>" & LF
                 & "  => null" & LF & "  ;",
                 1);
            Marked_Null : constant Silent_Handler_Info :=
              Inspect_Silent_Handler
                ("when others =>" & LF
                 & "  --  intentional terminal exception barrier" & LF
                 & "  null;",
                 1);
            Returning : constant Silent_Handler_Info :=
              Inspect_Silent_Handler ("when others => return;", 1);
            Wrapped : constant Silent_Handler_Info :=
              Inspect_Silent_Handler
                ("when others => begin" & LF
                 & "  null;" & LF
                 & "end;" & LF
                 & "end;",
                 1);
            Labeled : constant Silent_Handler_Info :=
              Inspect_Silent_Handler
                ("when others =>" & LF
                 & "  <<Ignored>>" & LF
                 & "  null;" & LF
                 & "end;",
                 1);
            Pragmatic : constant Silent_Handler_Info :=
              Inspect_Silent_Handler
                ("when others =>" & LF
                 & "  pragma Warnings (Off);" & LF
                 & "  null;" & LF
                 & "end;",
                 1);
            Followed_By_Action : constant Silent_Handler_Info :=
              Inspect_Silent_Handler
                ("when others => null; Recover;" & LF & "end;", 1);
         begin
            if not Split_Null.Is_Silent
              or else Split_Null.Intentional
              or else not Marked_Null.Is_Silent
              or else not Marked_Null.Intentional
              or else not Returning.Is_Silent
              or else Returning.Intentional
              or else not Wrapped.Is_Silent
              or else not Labeled.Is_Silent
              or else not Pragmatic.Is_Silent
              or else Followed_By_Action.Is_Silent
            then
               Tooling_Checks.Fail
                 ("silent broad exception handler parser self-test failed");
            end if;
         end;

         for Source_Root of Source_Roots loop
            for Path of Project_Tools.Files.List_Tree
              (Project_Tools.Files.Join (Root, To_String (Source_Root)))
            loop
               declare
                  File_Path : constant String := To_String (Path);
                  Content   : constant String :=
                    (if Project_Tools.Text.Ends_With (File_Path, ".adb")
                       or else Project_Tools.Text.Ends_With (File_Path, ".ads")
                     then Project_Tools.Files.Read_Raw_File (File_Path)
                     else "");

                  procedure Check_Handler
                    (Line_Number : Positive;
                     Source_Line : String)
                  is
                     pragma Unreferenced (Source_Line);
                     Info : constant Silent_Handler_Info :=
                       Inspect_Silent_Handler (Content, Line_Number);
                  begin
                     if Info.Is_Silent and then not Info.Intentional
                     then
                        Tooling_Checks.Fail
                          ("silent broad exception handler is prohibited in "
                           & File_Path & ":" & Positive'Image (Line_Number));
                     end if;
                  end Check_Handler;
               begin
                  if Content /= "" then
                     Project_Tools.Ada_Source.Scan_Broad_Exception_Handlers
                       (File_Path, Check_Handler'Access);
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
            if not Posix_Tools.Text.Matching.Contains
              (Catalog,
               ASCII.LF & Locale & "." & Messages.Key (Message) & " = ")
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
      Require_Catalog_Defaults
        ("tools/sed/share/sed/messages/catalog.txt", "tools/sed/src/library/sed-localization-defaults.adb");
      Require_Catalog_Defaults
        ("tools/awk/resources/messages/catalog.txt", "tools/awk/src/library/awk_cli-localization-defaults.adb");
      Check_No_Literal_Usage_Messages;
      Require_Usage_Messages_Catalogued;
      Require_Message_Keys_Catalogued;
   end Run;
end Metadata_Checks.Manifests;
