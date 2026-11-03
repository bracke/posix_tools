with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Ada.Characters.Handling;
with Package_Entries;
with Posix_Tools.Command_Inventory;
with Project_Tools.Ada_Source;
with Project_Tools.Alire_Manifests.Validation;
with Project_Tools.Files;
with Project_Tools.Text;
with Tooling_Checks;
with Tooling_Support;

package body Metadata_Checks.Source_Rules is
   use Ada.Strings.Unbounded;

   function Simple_Name (Path : String) return String is
   begin
      for Index in reverse Path'Range loop
         if Path (Index) = '/' or else Path (Index) = '\' then
            return Path (Index + 1 .. Path'Last);
         end if;
      end loop;
      return Path;
   end Simple_Name;

   function Starts_With (Text, Prefix : String) return Boolean is
     (Text'Length >= Prefix'Length
      and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

   procedure Require_Command_Boundary is
      Sources : constant Project_Tools.Files.Path_List :=
        Project_Tools.Files.List_Tree
          (Project_Tools.Files.Join (Tooling_Support.Root, "common/src"));
      No_Units : constant Project_Tools.Ada_Source.String_List :=
        [1 .. 0 => <>];
      Forbidden_Prefixes : constant Project_Tools.Ada_Source.String_List :=
        [To_Unbounded_String ("Hostkit"),
         To_Unbounded_String ("Messages"),
         To_Unbounded_String ("Terminal_Styles"),
         To_Unbounded_String ("AUnit"),
         To_Unbounded_String ("Project_Tools"),
         To_Unbounded_String ("Ada.Text_IO"),
         To_Unbounded_String ("Ada.Environment_Variables"),
         To_Unbounded_String ("Ada.Directories"),
         To_Unbounded_String ("Ada.Command_Line"),
         To_Unbounded_String ("GNAT.OS_Lib")];
   begin
      for Source of Sources loop
         declare
            Path : constant String := To_String (Source);
            Name : constant String := Simple_Name (Path);
         begin
            if Starts_With (Name, "posix_tools-commands-")
              and then Name'Length > 4
              and then Name (Name'Last - 3 .. Name'Last) in ".adb" | ".ads"
            then
               for Prefix of Forbidden_Prefixes loop
                  Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
                    (Source_Path => Path,
                     Prefix      => To_String (Prefix),
                     Allowed     => No_Units,
                     Quiet       => True);
               end loop;
            end if;
         end;
      end loop;
   end Require_Command_Boundary;

   procedure Require_Production_Boundaries is
      Sources : constant Project_Tools.Files.Path_List :=
        Project_Tools.Files.List_Tree
          (Project_Tools.Files.Join (Tooling_Support.Root, "common/src"));
      No_Units : constant Project_Tools.Ada_Source.String_List :=
        [1 .. 0 => <>];

      procedure Forbid
        (Path   : String;
         Prefix : String) is
      begin
         Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
           (Source_Path => Path,
            Prefix      => Prefix,
            Allowed     => No_Units,
            Quiet       => True);
      end Forbid;
   begin
      for Source of Sources loop
         declare
            Path : constant String := To_String (Source);
            Name : constant String := Simple_Name (Path);
         begin
            if Name'Length > 4
              and then Name (Name'Last - 3 .. Name'Last) in ".adb" | ".ads"
            then
               --  OS bindings belong behind the adapter boundary.
               if not Starts_With (Name, "posix_tools-host_adapters-") then
                  Forbid (Path, "Hostkit");
               end if;

               --  Rendering and catalog engines each have one owning unit.
               if not Starts_With (Name, "posix_tools-localization.") then
                  Forbid (Path, "Messages");
               end if;
               if not Starts_With (Name, "posix_tools-presentation.") then
                  Forbid (Path, "Terminal_Styles");
               end if;
            end if;
         end;
      end loop;
   end Require_Production_Boundaries;

   procedure Require_Wrapper_Boundary is
      No_Units : constant Project_Tools.Ada_Source.String_List :=
        [1 .. 0 => <>];
      Forbidden_Prefixes : constant Project_Tools.Ada_Source.String_List :=
        [To_Unbounded_String ("Ada"),
         To_Unbounded_String ("GNAT"),
         To_Unbounded_String ("Hostkit"),
         To_Unbounded_String ("Messages"),
         To_Unbounded_String ("Terminal_Styles"),
         To_Unbounded_String ("AUnit"),
         To_Unbounded_String ("Project_Tools")];
   begin
      for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Path : constant String :=
              Project_Tools.Files.Join
                (Tooling_Support.Root,
                 Posix_Tools.Command_Inventory.Wrapper_Path (Index));
         begin
            for Prefix of Forbidden_Prefixes loop
               Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses
                 (Source_Path => Path,
                  Prefix      => To_String (Prefix),
                  Allowed     => No_Units,
                  Quiet       => True);
            end loop;
         end;
      end loop;
   end Require_Wrapper_Boundary;

   procedure Require_Warning_Clean_Projects is
      function Without_Comments (Content : String) return String is
         Result    : Unbounded_String;
         Index     : Natural := Content'First;
         In_String : Boolean := False;
      begin
         while Index <= Content'Last loop
            if not In_String
              and then Index < Content'Last
              and then Content (Index .. Index + 1) = "--"
            then
               while Index <= Content'Last and then Content (Index) /= Character'Val (10) loop
                  Index := Index + 1;
               end loop;
            elsif Content (Index) = '"' then
               Append (Result, Content (Index));
               if In_String
                 and then Index < Content'Last
                 and then Content (Index + 1) = '"'
               then
                  Index := Index + 1;
                  Append (Result, Content (Index));
               else
                  In_String := not In_String;
               end if;
               Index := Index + 1;
            else
               Append (Result, Content (Index));
               Index := Index + 1;
            end if;
         end loop;
         return To_String (Result);
      end Without_Comments;

      function Compact (Content : String) return String is
         Result : Unbounded_String;
      begin
         for Ch of Content loop
            if Ch not in ' ' | Character'Val (9) | Character'Val (10) | Character'Val (13) then
               Append (Result, Ada.Characters.Handling.To_Lower (Ch));
            end if;
         end loop;
         return To_String (Result);
      end Compact;

      function Rejects_Warnings (Raw_Content : String) return Boolean is
         use Ada.Strings.Fixed;
         Content : constant String := Compact (Without_Comments (Raw_Content));
         Anchor  : constant String := "fordefault_switches(""ada"")use";
         Cursor  : Natural := Content'First;
         Found   : Boolean := False;
      begin
         while Cursor <= Content'Last loop
            declare
               First : constant Natural := Index (Content, Anchor, Cursor);
            begin
               exit when First = 0;
               Found := True;
               declare
                  Last : constant Natural := Index (Content, ";", First + Anchor'Length);
               begin
                  if Last = 0
                    or else Index (Content (First .. Last), """-gnatwe""") = 0
                    or else Index (Content (First .. Last), """-gnatws""") /= 0
                    or else Index (Content (First .. Last), """-gnatw-""") /= 0
                  then
                     return False;
                  end if;
                  Cursor := Last + 1;
               end;
            end;
         end loop;
         return Found;
      end Rejects_Warnings;

      procedure Check_Project (Relative_Path : String) is
      begin
         if Relative_Path'Length >= 4
           and then Relative_Path (Relative_Path'Last - 3 .. Relative_Path'Last) = ".gpr"
         then
            declare
               Path : constant String := Project_Tools.Files.Join (Tooling_Support.Root, Relative_Path);
            begin
               if not Rejects_Warnings (Project_Tools.Files.Read_Raw_File (Path)) then
                  Tooling_Checks.Fail
                    (Relative_Path & " must reject compiler warnings in its Ada Default_Switches");
               end if;
            end;
         end if;
      end Check_Project;

      procedure Check_Packaged_Projects is new Package_Entries (Check_Project);
   begin
      if Rejects_Warnings ("-- for Default_Switches (""Ada"") use (""-gnatwe"");")
        or else not Rejects_Warnings
          ("FOR Default_Switches(""ADA"") USE (""-gnatwa"", ""-gnatwe"");")
        or else Rejects_Warnings
          ("for Default_Switches (""Ada"") use (""-gnatwe"");"
           & "for Default_Switches (""Ada"") use (""-O2"");")
        or else Rejects_Warnings
          ("for Default_Switches (""Ada"") use (""-gnatwe"", ""-gnatws"");")
      then
         Tooling_Checks.Fail ("warning-policy parser self-test failed");
      end if;
      Check_Packaged_Projects;
   end Require_Warning_Clean_Projects;

   procedure Require_Line_Budget
     (Source_Path : String;
      Maximum     : Positive)
   is
      Content : constant String :=
        Project_Tools.Files.Read_Raw_File (Source_Path);
      Lines : Natural := 0;
   begin
      for Ch of Content loop
         if Ch = Character'Val (10) then
            Lines := Lines + 1;
         end if;
      end loop;

      if Content /= "" and then Content (Content'Last) /= Character'Val (10) then
         Lines := Lines + 1;
      end if;

      if Lines > Maximum then
         Tooling_Checks.Fail
           (Source_Path & " exceeds the " & Natural'Image (Maximum)
            & " line test-source budget; split it into focused units");
      end if;
   end Require_Line_Budget;

   procedure Require_Test_Procedure_Budgets
     (Source_Path : String;
      Maximum     : Positive)
   is
      Content      : constant String :=
        Project_Tools.Files.Read_Raw_File (Source_Path);
      Active_Name  : Unbounded_String;
      Active_First : Natural := 0;
      Pending_Name : Unbounded_String;
      Pending_First : Natural := 0;
      Pending_Declaration : Unbounded_String;
      Line_Number  : Natural := 0;
      From         : Natural := Content'First;

      function Starts_Test_Procedure (Lower : String) return Boolean is
        (Project_Tools.Text.Starts_With (Lower, "procedure test_")
         or else
           (Project_Tools.Text.Starts_With (Lower, "procedure run")
            and then Project_Tools.Text.Starts_With
              (Simple_Name (Source_Path),
               "basic_tests-text_algorithms-")));

      --  A semicolon separates formal parameters while inside parentheses;
      --  only one at declaration level proves this is a body-less procedure.
      function Has_Declaration_Terminator (Declaration : String) return Boolean is
         Parenthesis_Depth : Natural := 0;
         In_String         : Boolean := False;
         Index             : Natural := Declaration'First;
      begin
         while Index <= Declaration'Last loop
            if Declaration (Index) = '"' then
               if In_String
                 and then Index < Declaration'Last
                 and then Declaration (Index + 1) = '"'
               then
                  Index := Index + 2;
               else
                  In_String := not In_String;
                  Index := Index + 1;
               end if;
            elsif not In_String and then Declaration (Index) = '(' then
               Parenthesis_Depth := Parenthesis_Depth + 1;
               Index := Index + 1;
            elsif not In_String and then Declaration (Index) = ')' then
               if Parenthesis_Depth > 0 then
                  Parenthesis_Depth := Parenthesis_Depth - 1;
               end if;
               Index := Index + 1;
            elsif not In_String
              and then Declaration (Index) = ';'
              and then Parenthesis_Depth = 0
            then
               return True;
            else
               Index := Index + 1;
            end if;
         end loop;
         return False;
      end Has_Declaration_Terminator;

      procedure Finish_Active (Last_Line : Natural) is
      begin
         if Length (Active_Name) > 0
           and then Last_Line >= Active_First
           and then Last_Line - Active_First + 1 > Maximum
         then
            Tooling_Checks.Fail
              (Source_Path & ":" & Natural'Image (Active_First)
               & " test procedure " & To_String (Active_Name)
               & " exceeds the " & Natural'Image (Maximum)
               & " line procedure budget; split its scenarios");
         end if;
         Active_Name := Null_Unbounded_String;
         Active_First := 0;
      end Finish_Active;

      procedure Check_Line (Raw_Line : String) is
         use Ada.Strings.Fixed;
         Comment : constant Natural := Index (Raw_Line, "--");
         Code    : constant String :=
           Trim
             ((if Comment = 0
               then Raw_Line
               elsif Comment = Raw_Line'First
               then ""
               else Raw_Line (Raw_Line'First .. Comment - 1)),
              Ada.Strings.Both);
         Lower   : constant String :=
           Ada.Characters.Handling.To_Lower (Code);
      begin
         --  A new top-level test declaration is also a reliable upper bound
         --  for a preceding anonymous "end;".  This keeps the budget
         --  independent of whether declarations and endings use one line or
         --  several.
         if Starts_Test_Procedure (Lower) then
            Finish_Active (Line_Number - 1);
            Pending_Name := To_Unbounded_String
              (Project_Tools.Ada_Source.Token_After
                 (Code, "procedure "));
            Pending_First := Line_Number;
            Pending_Declaration := To_Unbounded_String (Lower);
         elsif Length (Pending_Name) > 0 then
            Append (Pending_Declaration, " " & Lower);
         end if;

         if Length (Pending_Name) > 0 then
            declare
               Declaration : constant String :=
                 To_String (Pending_Declaration);
            begin
               if Index (Declaration, " is") > 0 then
                  if Index (Declaration, "is separate") = 0 then
                     Active_Name := Pending_Name;
                     Active_First := Pending_First;
                  end if;
                  Pending_Name := Null_Unbounded_String;
                  Pending_First := 0;
                  Pending_Declaration := Null_Unbounded_String;
               elsif Has_Declaration_Terminator (Declaration) then
                  --  A body-less declaration is not a procedure body.
                  Pending_Name := Null_Unbounded_String;
                  Pending_First := 0;
                  Pending_Declaration := Null_Unbounded_String;
               end if;
            end;
         end if;

         if Length (Active_Name) > 0
           and then Lower =
           "end "
           & Ada.Characters.Handling.To_Lower (To_String (Active_Name))
           & ";"
         then
            Finish_Active (Line_Number);
         end if;
      end Check_Line;
   begin
      if Has_Declaration_Terminator
        ("procedure Test_Declaration (Left : Integer; Right : Integer)")
        or else not Has_Declaration_Terminator
          ("procedure Test_Declaration (Value : Integer);")
      then
         Tooling_Checks.Fail
           ("test procedure declaration parser self-test failed");
      end if;

      for Index in Content'Range loop
         if Content (Index) = Character'Val (10) then
            Line_Number := Line_Number + 1;
            Check_Line
              ((if Index = From then "" else Content (From .. Index - 1)));
            From := Index + 1;
         end if;
      end loop;
      if From <= Content'Last then
         Line_Number := Line_Number + 1;
         Check_Line (Content (From .. Content'Last));
      end if;
      Finish_Active (Line_Number);
   end Require_Test_Procedure_Budgets;

   procedure Require_Test_Source_Budgets is
      Sources : constant Project_Tools.Files.Path_List :=
        Project_Tools.Files.List_Tree
          (Project_Tools.Files.Join (Tooling_Support.Root, "tests/src"));
      Maximum_Body_Lines      : constant Positive := 1_400;
      Maximum_Spec_Lines      : constant Positive := 400;
      Maximum_Procedure_Lines : constant Positive := 500;
   begin
      for Source of Sources loop
         declare
            Path : constant String := To_String (Source);
         begin
            if Path'Length >= 4
              and then Path (Path'Last - 3 .. Path'Last) = ".adb"
            then
               Require_Line_Budget (Path, Maximum_Body_Lines);
               Require_Test_Procedure_Budgets
                 (Path, Maximum_Procedure_Lines);
            elsif Path'Length >= 4
              and then Path (Path'Last - 3 .. Path'Last) = ".ads"
            then
               Require_Line_Budget (Path, Maximum_Spec_Lines);
            end if;
         end;
      end loop;
   end Require_Test_Source_Budgets;

   procedure Run is
      Common_Manifest : constant String :=
        Project_Tools.Files.Join
          (Tooling_Support.Root, "common/alire.toml");
   begin
      Require_Crate_Metadata
        ("common/alire.toml", "posix_tools_common", "posix_tools_common.gpr");
      Project_Tools.Alire_Manifests.Validation.Require_Workspace_Pin
        (Common_Manifest, "hostkit", "../../hostkit", Quiet => True);
      Project_Tools.Alire_Manifests.Validation.Require_Workspace_Pin
        (Common_Manifest, "messages", "../../messages", Quiet => True);
      Project_Tools.Alire_Manifests.Validation.Require_Workspace_Pin
        (Common_Manifest,
         "terminal_styles",
         "../../terminal_styles",
         Quiet => True);

      Require_Command_Boundary;
      Require_Production_Boundaries;
      Require_Wrapper_Boundary;
      Require_Warning_Clean_Projects;
      Require_Test_Source_Budgets;
   end Run;
end Metadata_Checks.Source_Rules;
