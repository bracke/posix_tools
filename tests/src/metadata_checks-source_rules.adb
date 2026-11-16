with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Ada.Characters.Handling;
with Posix_Tools.Command_Inventory;
with Project_Tools.Ada_Source;
with Project_Tools.Alire_Manifests.Validation;
with Project_Tools.Files;
with Project_Tools.Text;
with Metadata_Checks.Ada_Lexing;
with Metadata_Checks.Warning_Policy;
with Tooling_Checks;
with Tooling_Support;

package body Metadata_Checks.Source_Rules is
   use Ada.Strings.Unbounded;

   package Procedure_Count_Maps is new
     Ada.Containers.Indefinite_Ordered_Maps
       (Key_Type     => String,
        Element_Type => Positive);

   procedure Increment
     (Counts : in out Procedure_Count_Maps.Map;
      Name   : String) is
   begin
      if Counts.Contains (Name) then
         Counts.Replace (Name, Counts.Element (Name) + 1);
      else
         Counts.Insert (Name, 1);
      end if;
   end Increment;

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

   function Registered_Test_Procedures return Procedure_Count_Maps.Map is
      Roots : constant Project_Tools.Files.Name_List :=
        [To_Unbounded_String ("tests/src"),
         To_Unbounded_String ("tools/explore/tests/src"),
         To_Unbounded_String ("tools/explore/e2e/src")];
      Result : Procedure_Count_Maps.Map;

      function Unit_Name_Of (Path : String) return String is
         File_Name : constant String := Simple_Name (Path);
         Last      : constant Natural := File_Name'Last - 4;
         Result    : String := File_Name (File_Name'First .. Last);
      begin
         for Ch of Result loop
            if Ch = '-' then
               Ch := '.';
            end if;
         end loop;
         return Ada.Characters.Handling.To_Lower (Result);
      end Unit_Name_Of;

   begin
      for Source_Root of Roots loop
         for Path of Project_Tools.Files.List_Tree
           (Project_Tools.Files.Join
              (Tooling_Support.Root, To_String (Source_Root)),
            "*.adb")
         loop
            declare
               Content : constant String :=
                 Metadata_Checks.Ada_Lexing.Code_View
                   (Project_Tools.Files.Read_Raw_File (To_String (Path)),
                    Keep_String_Delimiters => False);
               Lower   : constant String :=
                 Ada.Characters.Handling.To_Lower (Content);
               Cursor  : Natural := Lower'First;
               Registration_Unit : constant String :=
                 Unit_Name_Of (To_String (Path));
            begin
               while Cursor <= Lower'Last loop
                  declare
                     Marker : constant Natural :=
                       Ada.Strings.Fixed.Index
                         (Lower, "'access", Cursor);
                  begin
                     exit when Marker = 0;
                     declare
                        Statement_First : Natural := Marker;
                        Name_First      : Natural := Marker;
                        Name_Last       : constant Natural := Marker - 1;
                     begin
                        while Statement_First > Lower'First
                          and then Lower (Statement_First - 1) /= ';'
                        loop
                           Statement_First := Statement_First - 1;
                        end loop;
                        while Name_First > Statement_First
                          and then
                            (Project_Tools.Ada_Source.Is_Identifier_Character
                               (Lower (Name_First - 1))
                             or else Lower (Name_First - 1) = '.')
                        loop
                           Name_First := Name_First - 1;
                        end loop;

                        if Name_First <= Name_Last
                          and then Ada.Strings.Fixed.Index
                            (Lower (Statement_First .. Marker - 1),
                             ".create") > 0
                          and then Ada.Strings.Fixed.Index
                            (Lower (Statement_First .. Marker - 1),
                             "aunit.test_suites.add_test") > 0
                        then
                           declare
                              Qualified : constant String :=
                                Lower (Name_First .. Name_Last);
                           begin
                              Increment
                                (Result,
                                 Registration_Unit & "|" & Qualified);
                           end;
                        end if;
                     end;
                     Cursor := Marker + 7;
                  end;
               end loop;
            end;
         end loop;
      end loop;

      return Result;
   end Registered_Test_Procedures;

   procedure Require_Test_Procedure_Budgets
     (Source_Path : String;
      Maximum     : Positive;
      Registered  : Procedure_Count_Maps.Map;
      Measured    : in out Procedure_Count_Maps.Map)
   is
      Content      : constant String :=
        Project_Tools.Files.Read_Raw_File (Source_Path);
      Active_Name  : Unbounded_String;
      Active_First : Natural := 0;
      Active_Indent : Natural := 0;
      Pending_Name : Unbounded_String;
      Pending_First : Natural := 0;
      Pending_Indent : Natural := 0;
      Pending_Declaration : Unbounded_String;
      Procedure_Keyword_First : Natural := 0;
      Procedure_Keyword_Indent : Natural := 0;
      Line_Number  : Natural := 0;
      From         : Natural := Content'First;

      function Starts_Procedure (Lower : String) return Boolean is
        (Project_Tools.Text.Starts_With (Lower, "procedure ")
         or else Project_Tools.Text.Starts_With
           (Lower, "overriding procedure ")
         or else Project_Tools.Text.Starts_With
           (Lower, "not overriding procedure "));

      function Continues_Procedure (Lower : String) return Boolean is
        (Starts_Procedure ("procedure " & Lower));

      function Indentation (Line : String) return Natural is
         Result : Natural := 0;
      begin
         for Ch of Line loop
            exit when Ch not in ' ' | Character'Val (9);
            Result := Result + 1;
         end loop;
         return Result;
      end Indentation;

      function Unit_Name return String is
         Code : constant String :=
           Ada.Characters.Handling.To_Lower
             (Metadata_Checks.Ada_Lexing.Code_View
                (Content, Keep_String_Delimiters => False));
         First_Code : Natural := Code'First;
         File_Name : constant String := Simple_Name (Source_Path);
         Last      : constant Natural := File_Name'Last - 4;
         Result    : String := File_Name (File_Name'First .. Last);

         function Canonical_Parent_Name
           (First : Natural;
            Last  : Natural) return String
         is
            Parent            : Unbounded_String;
            Cursor            : Natural := First;
            Expect_Identifier : Boolean := True;
         begin
            while Cursor <= Last loop
               while Cursor <= Last
                 and then Code (Cursor) in ' ' | Character'Val (9)
                   | Character'Val (10) | Character'Val (13)
               loop
                  Cursor := Cursor + 1;
               end loop;
               exit when Cursor > Last;

               if Expect_Identifier then
                  if not Project_Tools.Ada_Source.Is_Identifier_Character
                    (Code (Cursor))
                  then
                     return "";
                  end if;
                  declare
                     Token_First : constant Natural := Cursor;
                  begin
                     while Cursor <= Last
                       and then Project_Tools.Ada_Source.Is_Identifier_Character
                         (Code (Cursor))
                     loop
                        Cursor := Cursor + 1;
                     end loop;
                     Append (Parent, Code (Token_First .. Cursor - 1));
                  end;
                  Expect_Identifier := False;
               elsif Code (Cursor) = '.' then
                  Append (Parent, '.');
                  Cursor := Cursor + 1;
                  Expect_Identifier := True;
               else
                  return "";
               end if;
            end loop;

            return
              (if Expect_Identifier or else Length (Parent) = 0
               then ""
               else To_String (Parent));
         end Canonical_Parent_Name;
      begin
         while First_Code <= Code'Last
           and then Code (First_Code) in ' ' | Character'Val (9)
             | Character'Val (10) | Character'Val (13)
         loop
            First_Code := First_Code + 1;
         end loop;

         if First_Code + 7 <= Code'Last
           and then Code (First_Code .. First_Code + 7) = "separate"
           and then
             (First_Code + 8 > Code'Last
              or else not Project_Tools.Ada_Source.Is_Identifier_Character
                (Code (First_Code + 8)))
         then
            declare
               Open  : constant Natural :=
                 Ada.Strings.Fixed.Index (Code, "(", First_Code + 8);
               First : constant Natural := Open + 1;
               Close : constant Natural :=
                 (if Open = 0
                  then 0
                  else Ada.Strings.Fixed.Index (Code, ")", First));
            begin
               if Open > 0 and then Close > First then
                  declare
                     Parent : constant String :=
                       Canonical_Parent_Name (First, Close - 1);
                  begin
                     if Parent /= "" then
                        return Parent;
                     end if;
                  end;
               end if;
            end;
         end if;
         for Ch of Result loop
            if Ch = '-' then
               Ch := '.';
            end if;
         end loop;
         return Ada.Characters.Handling.To_Lower (Result);
      end Unit_Name;

      function Is_Registered_Test (Name : String) return Boolean is
         Lower_Name : constant String :=
           Ada.Characters.Handling.To_Lower (Name);
      begin
         for Position in Registered.Iterate loop
            declare
               Registration : constant String :=
                 Procedure_Count_Maps.Key (Position);
               Bar : constant Natural :=
                 Ada.Strings.Fixed.Index (Registration, "|");
               Reference : constant String :=
                 Registration (Bar + 1 .. Registration'Last);
               Dot : constant Natural :=
                 Ada.Strings.Fixed.Index
                   (Reference, ".", Going => Ada.Strings.Backward);
               Simple : constant String :=
                 (if Dot = 0
                  then Reference
                  else Reference (Dot + 1 .. Reference'Last));
            begin
               if (Project_Tools.Text.Starts_With (Lower_Name, "test_")
                   and then Simple = Lower_Name)
                 or else Reference = Unit_Name & "." & Lower_Name
               then
                  return True;
               end if;
            end;
         end loop;
         return False;
      end Is_Registered_Test;

      procedure Record_Measured (Name : String) is
         Lower_Name : constant String :=
           Ada.Characters.Handling.To_Lower (Name);
         Qualified : constant String := Unit_Name & "." & Lower_Name;
      begin
         Increment (Measured, Qualified);
      end Record_Measured;

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

      type Procedure_Body_Kind is
        (No_Body, Ordinary_Body, Separate_Body, Generic_Instantiation);

      function Body_Kind_Of
        (Declaration : String) return Procedure_Body_Kind
      is
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
              and then Parenthesis_Depth = 0
              and then Project_Tools.Ada_Source.Is_Identifier_Character
                (Declaration (Index))
            then
               declare
                  First : constant Positive := Index;
               begin
                  while Index <= Declaration'Last
                    and then Project_Tools.Ada_Source.Is_Identifier_Character
                      (Declaration (Index))
                  loop
                     Index := Index + 1;
                  end loop;
                  if Ada.Characters.Handling.To_Lower
                    (Declaration (First .. Index - 1)) = "is"
                  then
                     while Index <= Declaration'Last
                       and then Declaration (Index) in ' ' | Character'Val (9)
                         | Character'Val (10) | Character'Val (13)
                     loop
                        Index := Index + 1;
                     end loop;
                     if Index <= Declaration'Last
                       and then Project_Tools.Ada_Source.Is_Identifier_Character
                         (Declaration (Index))
                     then
                        declare
                           Next_First : constant Positive := Index;
                        begin
                           while Index <= Declaration'Last
                             and then Project_Tools.Ada_Source.Is_Identifier_Character
                               (Declaration (Index))
                           loop
                              Index := Index + 1;
                           end loop;
                           if Ada.Characters.Handling.To_Lower
                             (Declaration (Next_First .. Index - 1)) = "separate"
                           then
                              return Separate_Body;
                           elsif Ada.Characters.Handling.To_Lower
                             (Declaration (Next_First .. Index - 1)) = "new"
                           then
                              return Generic_Instantiation;
                           end if;
                        end;
                     end if;
                     return Ordinary_Body;
                  end if;
               end;
            else
               Index := Index + 1;
            end if;
         end loop;
         return No_Body;
      end Body_Kind_Of;

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
         Active_Indent := 0;
      end Finish_Active;

      procedure Start_Pending
        (Declaration_Code  : String;
         Declaration_Lower : String;
         First_Line        : Natural;
         Indent            : Natural) is
      begin
         Finish_Active (First_Line - 1);
         declare
            Lower_Code : constant String :=
              Ada.Characters.Handling.To_Lower (Declaration_Code);
            Marker     : constant Natural :=
              Ada.Strings.Fixed.Index (Lower_Code, "procedure ");
         begin
            Pending_Name := To_Unbounded_String
              (Project_Tools.Ada_Source.Token_After
                 (Lower_Code (Marker .. Lower_Code'Last), "procedure "));
         end;
         Pending_First := First_Line;
         Pending_Indent := Indent;
         Pending_Declaration := To_Unbounded_String (Declaration_Lower);
      end Start_Pending;

      procedure Check_Line (Raw_Line : String) is
         use Ada.Strings.Fixed;
         Code    : constant String :=
           Trim
             (Metadata_Checks.Ada_Lexing.Code_View (Raw_Line),
              Ada.Strings.Both);
         Lower   : constant String :=
           Ada.Characters.Handling.To_Lower (Code);
         Indent  : constant Natural := Indentation (Raw_Line);
      begin
         if Length (Pending_Name) > 0 then
            Append (Pending_Declaration, " " & Lower);
         elsif Length (Active_Name) = 0 then
            if Procedure_Keyword_First > 0 then
               if Lower = "" then
                  null;
               elsif Continues_Procedure (Lower) then
                  Start_Pending
                    ("procedure " & Code,
                     "procedure " & Lower,
                     Procedure_Keyword_First,
                     Procedure_Keyword_Indent);
                  Procedure_Keyword_First := 0;
                  Procedure_Keyword_Indent := 0;
               else
                  Procedure_Keyword_First := 0;
                  Procedure_Keyword_Indent := 0;
               end if;
            elsif Starts_Procedure (Lower) then
               Start_Pending (Code, Lower, Line_Number, Indent);
            elsif Lower = "procedure" then
               Procedure_Keyword_First := Line_Number;
               Procedure_Keyword_Indent := Indent;
            end if;
         else
            --  A Test_* declaration inside an active test is nested. Keep
            --  measuring the outer procedure until its named end.
            Procedure_Keyword_First := 0;
         end if;

         if Length (Pending_Name) > 0 then
            declare
               Declaration : constant String :=
                 To_String (Pending_Declaration);
               Kind        : constant Procedure_Body_Kind :=
                 Body_Kind_Of (Declaration);
            begin
               if Kind /= No_Body then
                  if Kind = Ordinary_Body
                    and then
                      (Is_Registered_Test (To_String (Pending_Name))
                       or else Project_Tools.Text.Starts_With
                         (To_String (Pending_Name), "test_"))
                  then
                     Active_Name := Pending_Name;
                     Active_First := Pending_First;
                     Active_Indent := Pending_Indent;
                     if Is_Registered_Test (To_String (Pending_Name)) then
                        Record_Measured (To_String (Pending_Name));
                     end if;
                  end if;
                  Pending_Name := Null_Unbounded_String;
                  Pending_First := 0;
                  Pending_Indent := 0;
                  Pending_Declaration := Null_Unbounded_String;
               elsif Has_Declaration_Terminator (Declaration) then
                  --  A body-less declaration is not a procedure body.
                  Pending_Name := Null_Unbounded_String;
                  Pending_First := 0;
                  Pending_Indent := 0;
                  Pending_Declaration := Null_Unbounded_String;
               end if;
            end;
         end if;

         if Length (Active_Name) > 0
           and then
             (Lower =
                "end "
                & Ada.Characters.Handling.To_Lower (To_String (Active_Name))
                & ";"
              or else (Lower = "end;" and then Indent = Active_Indent))
         then
            Finish_Active (Line_Number);
         end if;
      end Check_Line;

   begin
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

   procedure Self_Test is separate;

   procedure Require_Test_Source_Budgets is
      Roots : constant Project_Tools.Files.Name_List :=
        [To_Unbounded_String ("tests/src"),
         To_Unbounded_String ("tools/explore/tests/src"),
         To_Unbounded_String ("tools/explore/e2e/src")];
      Registered : constant Procedure_Count_Maps.Map :=
        Registered_Test_Procedures;
      Measured : Procedure_Count_Maps.Map;
      Resolved : Procedure_Count_Maps.Map;
      Maximum_Body_Lines      : constant Positive := 1_200;
      Maximum_Spec_Lines      : constant Positive := 400;
      Maximum_Procedure_Lines : constant Positive := 425;

   begin
      for Source_Root of Roots loop
         for Source of Project_Tools.Files.List_Tree
           (Project_Tools.Files.Join
              (Tooling_Support.Root, To_String (Source_Root)))
         loop
            declare
               Path : constant String := To_String (Source);
            begin
               if Path'Length >= 4
                 and then Path (Path'Last - 3 .. Path'Last) = ".adb"
               then
                  Require_Line_Budget (Path, Maximum_Body_Lines);
                  Require_Test_Procedure_Budgets
                    (Path,
                     Maximum_Procedure_Lines,
                     Registered,
                     Measured);
               elsif Path'Length >= 4
                 and then Path (Path'Last - 3 .. Path'Last) = ".ads"
               then
                  Require_Line_Budget (Path, Maximum_Spec_Lines);
               end if;
            end;
         end loop;
      end loop;

      --  Resolve each access expression to one actual unit and procedure.
      --  Unqualified names first bind to a body in the registration unit;
      --  otherwise a unique project-wide suffix is accepted. Ambiguity must
      --  be removed at the registration site with a full qualification.
      for Position in Registered.Iterate loop
         declare
            Registration : constant String :=
              Procedure_Count_Maps.Key (Position);
            Expected : constant Positive :=
              Procedure_Count_Maps.Element (Position);
            Bar : constant Natural :=
              Ada.Strings.Fixed.Index (Registration, "|");
            Source_Unit : constant String :=
              Registration (Registration'First .. Bar - 1);
            Reference : constant String :=
              Registration (Bar + 1 .. Registration'Last);
            Dot : constant Natural :=
              Ada.Strings.Fixed.Index
                (Reference, ".", Going => Ada.Strings.Backward);
            Simple : constant String :=
              (if Dot = 0
               then Reference
               else Reference (Dot + 1 .. Reference'Last));
            Local : constant String := Source_Unit & "." & Simple;
            Match : Unbounded_String;
            Matches : Natural := 0;
         begin
            if Measured.Contains (Reference) then
               Match := To_Unbounded_String (Reference);
               Matches := 1;
            elsif Dot = 0 and then Measured.Contains (Local) then
               Match := To_Unbounded_String (Local);
               Matches := 1;
            else
               for Body_Position in Measured.Iterate loop
                  declare
                     Body_Name : constant String :=
                       Procedure_Count_Maps.Key (Body_Position);
                     Suffix : constant String := "." & Simple;
                  begin
                     if Body_Name'Length > Suffix'Length
                       and then Body_Name
                         (Body_Name'Last - Suffix'Length + 1 .. Body_Name'Last) =
                           Suffix
                     then
                        Match := To_Unbounded_String (Body_Name);
                        Matches := Matches + 1;
                     end if;
                  end;
               end loop;
            end if;

            if Matches = 0 then
               Tooling_Checks.Fail
                 ("registered test procedure " & Reference
                  & " in " & Source_Unit & " has no body");
            elsif Matches > 1 then
               Tooling_Checks.Fail
                 ("registered test procedure " & Reference
                  & " in " & Source_Unit
                  & " is ambiguous; qualify the access with its full unit");
            elsif Measured.Element (To_String (Match)) /= 1 then
               Tooling_Checks.Fail
                 ("registered test procedure " & To_String (Match)
                  & " violates the unique-name registration policy; register "
                  & "a uniquely named, non-overloaded wrapper");
            else
               for Count in 1 .. Expected loop
                  Increment (Resolved, To_String (Match));
               end loop;
            end if;
         end;
      end loop;

      for Position in Resolved.Iterate loop
         declare
            Registration : constant String :=
              Procedure_Count_Maps.Key (Position);
            Expected : constant Positive :=
              Procedure_Count_Maps.Element (Position);
            Actual : constant Natural :=
              (if Measured.Contains (Registration)
               then Measured.Element (Registration)
               else 0);
         begin
            if Actual < Expected then
               Tooling_Checks.Fail
                 ("registered test procedure " & Registration
                  & " has" & Natural'Image (Expected)
                  & " registrations but only" & Natural'Image (Actual)
                  & " bodies were found by the procedure-budget parser");
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
      Metadata_Checks.Warning_Policy.Run;
      Require_Test_Source_Budgets;
   end Run;
end Metadata_Checks.Source_Rules;
