with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Hostkit.Fs;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Line_Breaks;
with Posix_Tools.Text.Matching;
with Project_Tools.Files;
with Project_Tools.Text;
with Regression_Registry;
with Registered_Tests;
with Test_Selection;
with Tooling_Checks;
with Tooling_Steps;
with Tooling_Support;

package body Conformance_Checks is
   use Tooling_Support;

   package Regression_Id_Sets is new
     Ada.Containers.Indefinite_Ordered_Sets (String);

   procedure Run is
      use Ada.Strings.Unbounded;
      Check : constant Tooling_Checks.Checker :=
        Tooling_Checks.Create (Root);
      Requirements : constant String :=
        Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "generated/requirements.csv"));
      Inventory_Csv : constant String :=
        Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "generated/command_inventory.csv"));
      Requirement_Regression_Ids : Regression_Id_Sets.Set;
      Known_Regression_Ids       : Regression_Id_Sets.Set;

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

      function Is_Repository_Relative_Path (Path : String) return Boolean is
         Segment_First : Positive := Path'First;

         function Invalid_Segment (First : Positive; Last : Natural) return Boolean is
           (Last < First
            or else Path (First .. Last) = "."
            or else Path (First .. Last) = "..");
      begin
         if Path = ""
           or else Path (Path'First) in '/' | '\'
           or else
             (Path'Length >= 2 and then Path (Path'First + 1) = ':')
         then
            return False;
         end if;

         for Index in Path'Range loop
            if Path (Index) in '/' | '\' then
               if Invalid_Segment (Segment_First, Index - 1) then
                  return False;
               end if;
               Segment_First := Index + 1;
            end if;
         end loop;
         return not Invalid_Segment (Segment_First, Path'Last);
      end Is_Repository_Relative_Path;

      function Resolves_Within_Root (Path : String) return Boolean is
         Resolved_Root : constant String := Hostkit.Fs.Real_Path (Root);
         Resolved_Path : constant String := Hostkit.Fs.Real_Path (Path);
         Boundary      : Natural;
      begin
         if Resolved_Root = "" or else Resolved_Path = "" then
            return False;
         elsif Resolved_Path = Resolved_Root then
            return True;
         elsif Resolved_Path'Length <= Resolved_Root'Length
           or else Resolved_Path
             (Resolved_Path'First
              .. Resolved_Path'First + Resolved_Root'Length - 1) /=
               Resolved_Root
         then
            return False;
         end if;

         Boundary := Resolved_Path'First + Resolved_Root'Length;
         return Resolved_Path (Boundary) in '/' | '\';
      end Resolves_Within_Root;

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
         elsif not Is_Repository_Relative_Path (Reference) then
            return False;
         else
            declare
               Direct : constant String :=
                 Project_Tools.Files.Join (Root, Reference);
            begin
               if Project_Tools.Files.File_Exists (Direct)
                 or else Project_Tools.Files.Directory_Exists (Direct)
               then
                  return Resolves_Within_Root (Direct);
               elsif Is_Bare_File_Name (Reference) then
                  declare
                     Found : constant String :=
                       Project_Tools.Files.Find_File (Root, Reference);
                  begin
                     return Found /= "" and then Resolves_Within_Root (Found);
                  end;
               else
                  return False;
               end if;
            end;
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
        (Known_Regression_Ids.Contains (Name));

      procedure Load_Regression_Ids is
         procedure Remember
           (Line_Number : Positive;
            Id          : String;
            Command     : String;
            Summary     : String;
            Tests       : String)
         is
            pragma Unreferenced
              (Line_Number, Command, Summary, Tests);
         begin
            Known_Regression_Ids.Include (Id);
         end Remember;
      begin
         Regression_Registry.For_Each_Row (Remember'Access);
      end Load_Regression_Ids;

      function Requirement_References_Regression (Name : String) return Boolean is
        (Requirement_Regression_Ids.Contains (Name));

      procedure Remember_Requirement_Regressions (References : String) is
         Prefix    : constant String := "regression ";
         Count     : Natural;
         Has_Empty : Boolean;

         procedure Remember (Reference : String) is
         begin
            if Reference'Length > Prefix'Length
              and then Reference
                (Reference'First .. Reference'First + Prefix'Length - 1) =
                  Prefix
            then
               Requirement_Regression_Ids.Include
                 (Reference
                    (Reference'First + Prefix'Length .. Reference'Last));
            end if;
         end Remember;
      begin
         Regression_Registry.For_Each_Test_Reference
           (References, Remember'Access, Count, Has_Empty);
      end Remember_Requirement_Regressions;

      --  "posix_tools_tests" and a subcommand the driver runs, or a test
      --  selector it accepts, judged by the tables the driver itself uses.
      function Is_Project_Tooling_Test (Reference : String) return Boolean is
         Driver   : constant String := "posix_tools_tests ";
         Suite    : constant String := "test --suite ";
         Category : constant String := "test --category ";

         function Starts_With (Text, Prefix : String) return Boolean is
           (Text'Length > Prefix'Length
            and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);
      begin
         if not Starts_With (Reference, Driver) then
            return False;
         end if;

         declare
            Rest : constant String := Reference (Reference'First + Driver'Length .. Reference'Last);
         begin
            if Starts_With (Rest, Suite) then
               return Test_Selection.Is_Suite (Rest (Rest'First + Suite'Length .. Rest'Last));
            elsif Starts_With (Rest, Category) then
               return Test_Selection.Is_Category (Rest (Rest'First + Category'Length .. Rest'Last));
            else
               return Tooling_Steps.Is_Subcommand (Rest);
            end if;
         end;
      end Is_Project_Tooling_Test;

      --  A test source: an existing file named for the tests it holds.
      function Is_Test_Source (Path : String) return Boolean is
         Suffix : constant String := "_tests.adb";
      begin
         return Path'Length > Suffix'Length
           and then Path (Path'Last - Suffix'Length + 1 .. Path'Last) = Suffix
           and then Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Path));
      end Is_Test_Source;

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
            return Is_Test_Source (Item);
         else
            return Registered_Tests.Is_Registered (Item) or else Is_Project_Tooling_Test (Item);
         end if;
      end Test_Reference_Exists;

      procedure Check_Implementation_References (Id_Text : String; Text : String) is
         Start : Positive := Text'First;
         Count : Natural := 0;

         procedure Check_Reference (Reference : String) is
            Item : constant String := Trimmed (Reference);
         begin
            if Item = "" then
               Tooling_Checks.Fail
                 (Id_Text & " contains an empty implementation reference");
            elsif not Implementation_Reference_Exists (Item) then
               Tooling_Checks.Fail
                 (Id_Text & " references missing implementation " & Item);
            end if;
            Count := Count + 1;
         end Check_Reference;
      begin
         if Trimmed (Text) = "" then
            Tooling_Checks.Fail
              (Id_Text & " has no implementation references");
         end if;

         for I in Text'Range loop
            if Text (I) = ';' then
               Check_Reference
                 ((if Start < I then Text (Start .. I - 1) else ""));
               Start := I + 1;
            end if;
         end loop;

         Check_Reference
           ((if Start <= Text'Last then Text (Start .. Text'Last) else ""));
         if Count = 0 then
            Tooling_Checks.Fail
              (Id_Text & " has no implementation references");
         end if;
      end Check_Implementation_References;

      procedure Check_Test_References (Id_Text : String; Text : String) is
         Reference_Count : Natural;
         Has_Empty       : Boolean;

         procedure Check_Reference (Reference : String) is
         begin
            if not Test_Reference_Exists (Reference) then
               Tooling_Checks.Fail
                 (Id_Text
                  & " references missing test or validation artifact "
                  & Reference);
            end if;
         end Check_Reference;
      begin
         if Trimmed (Text) = "" then
            Tooling_Checks.Fail
              (Id_Text & " has no test references");
         end if;
         Regression_Registry.For_Each_Test_Reference
           (Text,
            Check_Reference'Access,
            Reference_Count,
            Has_Empty);
         if Reference_Count = 0 then
            Tooling_Checks.Fail
              (Id_Text & " has no test references");
         elsif Has_Empty then
            Tooling_Checks.Fail
              (Id_Text & " contains an empty test reference");
         end if;
      end Check_Test_References;

      procedure Check_Regression_Row
        (Number      : Positive;
         Id_Text     : String;
         Test_Text   : String)
      is
         pragma Unreferenced (Number);
      begin
         if not Requirement_References_Regression (Id_Text) then
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
         elsif Trimmed (To_String (Row.Command)) = "" then
            Tooling_Checks.Fail
              (Id_Text & " has empty command field");
         elsif Trimmed (To_String (Row.Implementation)) = "" then
            Tooling_Checks.Fail
              (Id_Text & " has empty implementation field");
         elsif Trimmed (To_String (Row.Test)) = "" then
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
            Remember_Requirement_Regressions (Test_Text);
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
         Seen_Count : Natural := 0;

         procedure Check_Row
           (Line_Number : Positive;
            Id           : String;
            Command      : String;
            Summary      : String;
            Tests        : String)
         is
            pragma Unreferenced (Command, Summary);
         begin
            Check_Regression_Row
              (Line_Number,
               Id,
               Tests);
            Seen_Count := Seen_Count + 1;
         end Check_Row;
      begin
         Regression_Registry.For_Each_Row (Check_Row'Access);
         pragma Assert (Seen_Count > 0);
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
      if not Referenced_Path_Exists ("alire.toml")
        or else Referenced_Path_Exists ("../project_tools/alire.toml")
        or else Referenced_Path_Exists ("common/../alire.toml")
      then
         Tooling_Checks.Fail
           ("conformance repository-path confinement self-test failed");
      end if;
      Load_Regression_Ids;
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
