with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Line_Breaks;
with Posix_Tools.Text.Matching;
with Project_Tools.Files;
with Project_Tools.Text;
with Registered_Tests;
with Tooling_Checks;
with Tooling_Support;

package body Conformance_Checks is
   use Tooling_Support;

   procedure Run is
      use Ada.Strings.Unbounded;
      Check : constant Tooling_Checks.Checker :=
        Tooling_Checks.Create (Root);
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
         --  A pattern over every command stands for each command's file.
         if Reference = "generated/man/*.1" then
            return (for all I in 1 .. Posix_Tools.Command_Inventory.Command_Count =>
                      Project_Tools.Files.File_Exists
                        (Project_Tools.Files.Join
                           (Root, "generated/man/" & Posix_Tools.Command_Inventory.Executable (I) & ".1")));
         elsif Reference = "tools/*/src/*.adb" then
            return (for all I in 1 .. Posix_Tools.Command_Inventory.Command_Count =>
                      Project_Tools.Files.File_Exists
                        (Project_Tools.Files.Join (Root, Posix_Tools.Command_Inventory.Wrapper_Path (I))));
         elsif Reference = "tools/*/alire.toml" then
            return (for all I in 1 .. Posix_Tools.Command_Inventory.Command_Count =>
                      Project_Tools.Files.File_Exists
                        (Project_Tools.Files.Join (Root, Posix_Tools.Command_Inventory.Manifest_Path (I))));
         elsif Reference = "docs/commands/*.md" then
            return (for all I in 1 .. Posix_Tools.Command_Inventory.Command_Count =>
                      Project_Tools.Files.File_Exists
                        (Project_Tools.Files.Join (Root, Posix_Tools.Command_Inventory.Documentation_Path (I))));
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
            return Registered_Tests.Is_Registered (Item) or else Is_Project_Tooling_Test (Item);
         end if;
      end Test_Reference_Exists;

      procedure Check_Implementation_References (Id_Text : String; Text : String) is
         Start : Positive := Text'First;
      begin
         if Text = "" then
            Tooling_Checks.Fail
              (Id_Text & " has no implementation references");
         end if;

         for I in Text'Range loop
            if Text (I) = ';' then
               if Start <= I - 1
                 and then not Implementation_Reference_Exists (Text (Start .. I - 1))
               then
                  Tooling_Checks.Fail
                    (Id_Text & " references missing implementation " & Trimmed (Text (Start .. I - 1)));
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Text'Last
           and then not Implementation_Reference_Exists (Text (Start .. Text'Last))
         then
            Tooling_Checks.Fail
              (Id_Text & " references missing implementation " & Trimmed (Text (Start .. Text'Last)));
         end if;
      end Check_Implementation_References;

      procedure Check_Test_References (Id_Text : String; Text : String) is
         Start : Positive := Text'First;
      begin
         if Text = "" then
            Tooling_Checks.Fail
              (Id_Text & " has no test references");
         end if;

         for I in Text'Range loop
            if Text (I) = ';' then
               if Start <= I - 1
                 and then not Test_Reference_Exists (Text (Start .. I - 1))
               then
                  Tooling_Checks.Fail
                    (Id_Text & " references missing test or validation artifact "
                     & Trimmed (Text (Start .. I - 1)));
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Text'Last
           and then not Test_Reference_Exists (Text (Start .. Text'Last))
         then
            Tooling_Checks.Fail
              (Id_Text & " references missing test or validation artifact "
               & Trimmed (Text (Start .. Text'Last)));
         end if;
      end Check_Test_References;

      procedure Check_Regression_Row (Line : String; Number : Positive) is
         Id_Text : constant String := Field (Line, 1);
         Test_Text : constant String := Field (Line, 4);
      begin
         if Field_Count (Line) /= 4 then
            Tooling_Checks.Fail
              ("regression row has wrong field count at line" & Positive'Image (Number));
         elsif Id_Text = "" then
            Tooling_Checks.Fail
              ("regression row has empty identifier at line" & Positive'Image (Number));
         elsif not Is_Regression_Id (Id_Text) then
            Tooling_Checks.Fail
              (Id_Text & " has invalid regression identifier syntax");
         elsif Field (Line, 2) = "" then
            Tooling_Checks.Fail
              (Id_Text & " has empty command field");
         elsif Field (Line, 3) = "" then
            Tooling_Checks.Fail
              (Id_Text & " has empty summary field");
         elsif Test_Text = "" then
            Tooling_Checks.Fail
              (Id_Text & " has no linked regression test");
         elsif not Requirement_References_Regression (Id_Text) then
            Tooling_Checks.Fail
              (Id_Text & " is not referenced by any requirement row");
         else
            Check_Test_References (Id_Text, Test_Text);
         end if;
      end Check_Regression_Row;

      procedure Check_Inventory_Path (Executable : String; Path : String; Label : String) is
      begin
         if Path = "" then
            Tooling_Checks.Fail
              ("inventory row for " & Executable & " has empty " & Label);
         elsif not Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Path)) then
            Tooling_Checks.Fail
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
            Tooling_Checks.Fail
              ("inventory row for " & Executable & " has " & Label & " '" & Actual
               & "' but expected '" & Expected & "'");
         end if;
      end Require_Inventory_Field;

      procedure Check_Inventory_Row (Line : String; Number : Positive) is
         Index : constant Positive := Number - 1;
         Executable : constant String := Field (Line, 1);
      begin
         if Field_Count (Line) /= 11 then
            Tooling_Checks.Fail
              ("command inventory row has wrong field count at line" & Positive'Image (Number));
         elsif Index > Posix_Tools.Command_Inventory.Command_Count then
            Tooling_Checks.Fail
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
            Boolean_Text (Posix_Tools.Command_Inventory.Release_Included (Index)));
         Require_Inventory_Field
           (Executable, "POSIX status", Field (Line, 8), Posix_Tools.Command_Inventory.Posix_Status (Index));
         Require_Inventory_Field
           (Executable,
            "help flag",
            Field (Line, 9),
            Boolean_Text (Posix_Tools.Command_Inventory.Has_Help (Index)));
         Require_Inventory_Field
           (Executable,
            "version flag",
            Field (Line, 10),
            Boolean_Text (Posix_Tools.Command_Inventory.Has_Version (Index)));
         Require_Inventory_Field
           (Executable,
            "identity flag",
            Field (Line, 11),
            Boolean_Text (Posix_Tools.Command_Inventory.Has_Identity (Index)));

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
            Tooling_Checks.Fail
              ("requirement row has wrong field count at line" & Positive'Image (Number));
         elsif Id_Text = "" then
            Tooling_Checks.Fail
              ("requirement row has empty identifier at line" & Positive'Image (Number));
         elsif not Is_Requirement_Id (Id_Text) then
            Tooling_Checks.Fail
              (Id_Text & " has invalid requirement identifier syntax");
         elsif To_String (Row.Command) = "" then
            Tooling_Checks.Fail
              (Id_Text & " has empty command field");
         elsif To_String (Row.Implementation) = "" then
            Tooling_Checks.Fail
              (Id_Text & " has empty implementation field");
         elsif To_String (Row.Test) = "" then
            Tooling_Checks.Fail
              (Id_Text & " has no linked test or validation artifact");
         elsif not Is_Allowed_Status (Status_Text) then
            Tooling_Checks.Fail
              (Id_Text & " has invalid conformance status " & Status_Text);
         elsif Project_Tools.Text.Contains (To_String (Row.Posix_Reference), "POSIX.1-2008")
           or else Project_Tools.Text.Contains (To_String (Row.Posix_Reference), "POSIX.1-2017")
           or else Project_Tools.Text.Contains (To_String (Row.Posix_Reference), "Issue 7")
         then
            Tooling_Checks.Fail
              (Id_Text & " mixes an older POSIX baseline into the V1 registry");
         elsif To_String (Row.Posix_Reference) = "Project extension"
           and then not
             (Project_Tools.Text.Contains (Id_Text, "-EXT-")
              or else Posix_Tools.Text.Matching.Starts_With (Id_Text, "NONPOSIX-"))
         then
            Tooling_Checks.Fail
              (Id_Text & " records a project extension without an extension identifier");
         else
            Check_Implementation_References (Id_Text, Implementation_Text);
            Check_Test_References (Id_Text, Test_Text);
         end if;

         if Status_Text = "Known deviation"
           and then not Project_Tools.Text.Contains (Test_Text, "docs/")
         then
            Tooling_Checks.Fail
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
                  Tooling_Checks.Fail
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
                  Tooling_Checks.Fail
                    ("duplicate requirement identifier " & Id_Text
                     & " at line" & Positive'Image (Number));
               end if;
            end loop;

            if Seen_Count = Max_Requirement_Rows then
               Tooling_Checks.Fail ("requirements registry exceeds tooling row capacity");
            end if;

            Seen_Count := Seen_Count + 1;
            Seen_Ids (Seen_Count) := To_Unbounded_String (Id_Text);
         end Remember_Id;
      begin
         if Requirements = "" then
            Tooling_Checks.Fail ("requirements registry is empty");
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
                           Tooling_Checks.Fail ("requirements registry header is invalid");
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
                  Tooling_Checks.Fail
                    ("duplicate regression identifier " & Id_Text
                     & " at line" & Positive'Image (Number));
               end if;
            end loop;

            if Seen_Count = Max_Regression_Rows then
               Tooling_Checks.Fail ("regression registry exceeds tooling row capacity");
            end if;

            Seen_Count := Seen_Count + 1;
            Seen_Ids (Seen_Count) := To_Unbounded_String (Id_Text);
         end Remember_Id;
      begin
         if Regressions = "" then
            Tooling_Checks.Fail ("regression registry is empty");
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
                           Tooling_Checks.Fail ("regression registry header is invalid");
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
            Tooling_Checks.Fail ("command inventory is empty");
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
                           Tooling_Checks.Fail ("command inventory header is invalid");
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
            Tooling_Checks.Fail
              ("command inventory row count does not match compiled inventory");
         end if;
      end Check_Inventory_Rows;
   begin
      Check_Requirement_Rows;
      Check_Regression_Rows;
      Check_Inventory_Rows;
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         if not Has_Command_Metadata (Posix_Tools.Command_Inventory.Executable (I)) then
            Tooling_Checks.Fail
              ("released command lacks conformance metadata: "
               & Posix_Tools.Command_Inventory.Executable (I));
         end if;

         if Posix_Tools.Command_Inventory.Posix_Status (I) = "known_deviation" then
            if not Has_Known_Deviation_Metadata (Posix_Tools.Command_Inventory.Executable (I)) then
               Tooling_Checks.Fail
                 ("inventory command is marked known_deviation without matching requirement row: "
                  & Posix_Tools.Command_Inventory.Executable (I));
            end if;
         elsif Has_Known_Deviation_Metadata (Posix_Tools.Command_Inventory.Executable (I)) then
            Tooling_Checks.Fail
              ("requirement registry has a known deviation for inventory command not marked known_deviation: "
               & Posix_Tools.Command_Inventory.Executable (I));
         end if;
      end loop;
      Tooling_Checks.Require_Text
        (Check, "generated/requirements.csv", "Conforming with extensions");
      Tooling_Checks.Require_Text
        (Check, "docs/conformance.md", "POSIX.1-2024");
      Ada.Text_IO.Put_Line ("conformance metadata checks passed");
   end Run;
end Conformance_Checks;
