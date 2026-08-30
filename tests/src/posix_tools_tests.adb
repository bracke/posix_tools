with Ada.Command_Line;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Options;
with AUnit.Reporter.Text;
with AUnit.Run;
with AUnit.Test_Filters;
with All_Suites;
with Build_Checks;
with Format_Checks;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Host_Adapters.Executables;
with Posix_Tools.Paths;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Line_Breaks;
with Posix_Tools.Text.Matching;
with Posix_Tools.Version;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;
with Package_Entries;
with Proof_Targets;
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

   function Strip_Markdown_Ticks (Text : String) return String is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String;
   begin
      for Ch of Text loop
         if Ch /= '`' then
            Append (Result, Ch);
         end if;
      end loop;

      return To_String (Result);
   end Strip_Markdown_Ticks;

   function Trim_Blank_Lines (Text : String) return String is
      First : Natural := Text'First;
      Last  : Natural := Text'Last;
   begin
      if Text = "" then
         return "";
      end if;

      while First <= Text'Last
        and then (Text (First) = Character'Val (10) or else Text (First) = Character'Val (13))
      loop
         First := First + 1;
      end loop;

      while Last >= First
        and then (Text (Last) = Character'Val (10) or else Text (Last) = Character'Val (13))
      loop
         Last := Last - 1;
      end loop;

      if First > Last then
         return "";
      else
         return Text (First .. Last);
      end if;
   end Trim_Blank_Lines;

   function Markdown_Section (Document : String; Heading : String) return String is
      Marker : constant String := Character'Val (10) & "## " & Heading & Character'Val (10);
      First  : constant Natural := Ada.Strings.Fixed.Index (Document, Marker);
   begin
      if First = 0 then
         return "";
      else
         declare
            Start       : constant Natural := First + Marker'Length;
            Next_Header : constant Natural :=
              Ada.Strings.Fixed.Index
                (Document (Start .. Document'Last),
                 Character'Val (10) & "## ");
            Last        : constant Natural := (if Next_Header = 0 then Document'Last else Next_Header - 1);
         begin
            return Strip_Markdown_Ticks (Trim_Blank_Lines (Document (Start .. Last)));
         end;
      end if;
   end Markdown_Section;

   function Roff_Text (Text : String) return String is
      use Ada.Strings.Unbounded;
      Result        : Unbounded_String;
      At_Line_Start : Boolean := True;
   begin
      for Ch of Text loop
         if At_Line_Start and then (Ch = '.' or else Ch = Character'Val (39)) then
            Append (Result, "\&");
         end if;

         Append (Result, Ch);
         At_Line_Start := Ch = Character'Val (10);
      end loop;

      if Text = "" or else Text (Text'Last) /= Character'Val (10) then
         Append (Result, Character'Val (10));
      end if;

      return To_String (Result);
   end Roff_Text;

   function Command_Manpage (Index : Positive) return String is
      use Ada.Strings.Unbounded;
      Command  : constant String := Posix_Tools.Command_Inventory.Executable (Index);
      Document : constant String :=
        Project_Tools.Files.Read_Raw_File
          (Project_Tools.Files.Join (Root, Posix_Tools.Command_Inventory.Documentation_Path (Index)));
      Page     : Unbounded_String;

      procedure Append_Section (Heading : String; Source_Heading : String := "") is
         Source : constant String := (if Source_Heading = "" then Heading else Source_Heading);
         Text   : constant String := Markdown_Section (Document, Source);
      begin
         if Text /= "" then
            Append (Page, ".SH " & Heading & Character'Val (10));
            Append (Page, Roff_Text (Text));
         end if;
      end Append_Section;
   begin
      Append (Page, ".TH " & Command & " 1" & Character'Val (10));
      Append_Section ("NAME", "Name");
      Append_Section ("SYNOPSIS", "Synopsis");
      Append_Section ("DESCRIPTION", "Description");
      Append_Section ("OPERANDS", "Operands");
      Append_Section ("OPTIONS", "Options");
      Append_Section ("STANDARD INPUT", "Standard Input");
      Append_Section ("STANDARD OUTPUT", "Standard Output");
      Append_Section ("STANDARD ERROR", "Standard Error");
      Append_Section ("EXIT STATUS", "Exit Status");
      Append_Section ("BEHAVIORAL DETAILS", "Behavioral Details");
      Append_Section ("LOCALE BEHAVIOR", "Locale Behavior");
      Append_Section ("IMPLEMENTATION-DEFINED CHOICES", "Implementation-Defined Choices");
      Append_Section ("EXTENSIONS", "Extensions");
      Append_Section ("EXAMPLES", "Examples");
      Append_Section ("CONFORMANCE STATUS", "Conformance Status");
      Append_Section ("KNOWN LIMITATIONS", "Known Limitations");
      Append (Page, ".SH SEE ALSO" & Character'Val (10));
      Append (Page, Posix_Tools.Command_Inventory.Documentation_Path (Index) & Character'Val (10));

      return To_String (Page);
   end Command_Manpage;

   function Root_Manpage return String is
      use Ada.Strings.Unbounded;
      Document : constant String :=
        Project_Tools.Files.Read_Raw_File
          (Project_Tools.Files.Join (Root, "docs/commands/posix-tools.md"));
      Page     : Unbounded_String;

      procedure Append_Section (Heading : String; Source_Heading : String := "") is
         Source : constant String := (if Source_Heading = "" then Heading else Source_Heading);
         Text   : constant String := Markdown_Section (Document, Source);
      begin
         if Text /= "" then
            Append (Page, ".SH " & Heading & Character'Val (10));
            Append (Page, Roff_Text (Text));
         end if;
      end Append_Section;
   begin
      Append (Page, ".TH posix-tools 1" & Character'Val (10));
      Append_Section ("NAME", "Name");
      Append_Section ("SYNOPSIS", "Synopsis");
      Append_Section ("DESCRIPTION", "Description");
      Append_Section ("OPERANDS", "Operands");
      Append_Section ("OPTIONS", "Options");
      Append_Section ("STANDARD INPUT", "Standard Input");
      Append_Section ("STANDARD OUTPUT", "Standard Output");
      Append_Section ("STANDARD ERROR", "Standard Error");
      Append_Section ("EXIT STATUS", "Exit Status");
      Append_Section ("BEHAVIORAL DETAILS", "Behavioral Details");
      Append_Section ("LOCALE BEHAVIOR", "Locale Behavior");
      Append_Section ("IMPLEMENTATION-DEFINED CHOICES", "Implementation-Defined Choices");
      Append_Section ("EXTENSIONS", "Extensions");
      Append_Section ("EXAMPLES", "Examples");
      Append_Section ("CONFORMANCE STATUS", "Conformance Status");
      Append_Section ("KNOWN LIMITATIONS", "Known Limitations");
      Append (Page, ".SH SEE ALSO" & Character'Val (10));
      Append (Page, "docs/commands/posix-tools.md" & Character'Val (10));
      Append (Page, Character'Val (10));

      return To_String (Page);
   end Root_Manpage;

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

      procedure Require_Text_Before
        (Path          : String;
         Earlier_Text  : String;
         Later_Text    : String;
         Failure_Label : String)
      is
         Content : constant String :=
           Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));
         Earlier : constant Natural := Ada.Strings.Fixed.Index (Content, Earlier_Text);
         Later   : constant Natural := Ada.Strings.Fixed.Index (Content, Later_Text);
      begin
         if Earlier = 0 then
            Project_Tools.Release_Checks.Fail (Failure_Label & ": missing earlier marker");
         elsif Later = 0 then
            Project_Tools.Release_Checks.Fail (Failure_Label & ": missing later marker");
         elsif Earlier >= Later then
            Project_Tools.Release_Checks.Fail (Failure_Label & ": markers are out of order");
         end if;
      end Require_Text_Before;

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

      function Count_Exact_Lines (Text : String; Expected : String) return Natural is
         Start : Positive := Text'First;
         Count : Natural := 0;
      begin
         if Text = "" then
            return 0;
         end if;

         for I in Text'Range loop
            if Text (I) = Character'Val (10) then
               if I > Start
                 and then Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                   (Text (Start .. I - 1)) = Expected
               then
                  Count := Count + 1;
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Text'Last
           and then Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
             (Text (Start .. Text'Last)) = Expected
         then
            Count := Count + 1;
         end if;

         return Count;
      end Count_Exact_Lines;

      function Count_Prefix_Lines (Text : String; Prefix : String) return Natural is
         Start : Positive := Text'First;
         Count : Natural := 0;
      begin
         if Text = "" then
            return 0;
         end if;

         for I in Text'Range loop
            if Text (I) = Character'Val (10) then
               if I > Start
                 and then Posix_Tools.Text.Matching.Starts_With
                   (Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                      (Text (Start .. I - 1)),
                    Prefix)
               then
                  Count := Count + 1;
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Text'Last
           and then Posix_Tools.Text.Matching.Starts_With
             (Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                (Text (Start .. Text'Last)),
              Prefix)
         then
            Count := Count + 1;
         end if;

         return Count;
      end Count_Prefix_Lines;

      function Count_Nonempty_Lines (Text : String) return Natural is
         Start : Positive := Text'First;
         Count : Natural := 0;
      begin
         if Text = "" then
            return 0;
         end if;

         for I in Text'Range loop
            if Text (I) = Character'Val (10) then
               if I > Start
                 and then Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                   (Text (Start .. I - 1)) /= ""
               then
                  Count := Count + 1;
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Text'Last
           and then Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
             (Text (Start .. Text'Last)) /= ""
         then
            Count := Count + 1;
         end if;

         return Count;
      end Count_Nonempty_Lines;

      procedure Require_Exact_Line (Path : String; Line : String; Description : String) is
         Content : constant String := Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));
         Count   : constant Natural := Count_Exact_Lines (Content, Line);
      begin
         if Count = 0 then
            Project_Tools.Release_Checks.Fail (Description & " missing or stale in " & Path);
         elsif Count > 1 then
            Project_Tools.Release_Checks.Fail (Description & " duplicated in " & Path);
         end if;
      end Require_Exact_Line;

      function Proof_Unit_Name (Path : String) return String is
         use Ada.Characters.Handling;
         Name_First : Natural := Path'First;
         Name_Last  : Natural := Path'Last;
      begin
         for I in reverse Path'Range loop
            if Path (I) = '/' or else Path (I) = '\' then
               Name_First := I + 1;
               exit;
            end if;
         end loop;

         if Project_Tools.Text.Ends_With (Path, ".ads") then
            Name_Last := Path'Last - 4;
         end if;

         declare
            Name : String := To_Lower (Path (Name_First .. Name_Last));
         begin
            for Ch of Name loop
               if Ch = '-' then
                  Ch := '.';
               end if;
            end loop;
            return Name;
         end;
      end Proof_Unit_Name;

      procedure Require_All_SPARK_Specs_Are_Proof_Targets_And_Documented is
         use Ada.Strings.Unbounded;

         Proof_Driver : constant String :=
           Project_Tools.Files.Read_Raw_File
             (Project_Tools.Files.Join (Root, "tests/src/proof_targets.adb"));
         Proof_Document : constant String :=
           Ada.Characters.Handling.To_Lower
             (Project_Tools.Files.Read_Raw_File
                (Project_Tools.Files.Join (Root, "docs/proof-coverage.md")));
         Source_Roots : constant Project_Tools.Files.Name_List :=
           [To_Unbounded_String ("common/src"),
            To_Unbounded_String ("common/generated")];
      begin
         for Source_Root of Source_Roots loop
            for Path of Project_Tools.Files.List_Tree (Project_Tools.Files.Join (Root, To_String (Source_Root))) loop
               declare
                  File_Path : constant String := To_String (Path);
               begin
                  if Project_Tools.Text.Ends_With (File_Path, ".ads")
                    and then Project_Tools.Files.File_Contains (File_Path, "SPARK_Mode => On")
                  then
                     declare
                        Unit_Name : constant String := Proof_Unit_Name (File_Path);
                     begin
                        if not Posix_Tools.Text.Matching.Contains
                          (Proof_Driver, "To_Unbounded_String (""" & Unit_Name & """)")
                        then
                           Project_Tools.Release_Checks.Fail
                             ("SPARK unit is missing from proof targets: " & Unit_Name);
                        elsif not Posix_Tools.Text.Matching.Contains
                          (Proof_Document, "- `" & Unit_Name & "`")
                        then
                           Project_Tools.Release_Checks.Fail
                             ("SPARK unit is missing from proof coverage docs: " & Unit_Name);
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end loop;
      end Require_All_SPARK_Specs_Are_Proof_Targets_And_Documented;

      function Is_Documented_Non_SPARK_Boundary
        (Unit_Name      : String;
         Proof_Document : String) return Boolean
      is
         use Posix_Tools.Text.Matching;

         function Has_Entry (Name : String) return Boolean is
         begin
            return Contains (Proof_Document, "- `" & Name & "`");
         end Has_Entry;
      begin
         return
           Has_Entry (Unit_Name)
           or else
             (Starts_With (Unit_Name, "posix_tools.commands.")
              and then Has_Entry ("posix_tools.commands.*"))
           or else
             (Starts_With (Unit_Name, "posix_tools.host_adapters")
              and then Has_Entry ("posix_tools.host_adapters.*"));
      end Is_Documented_Non_SPARK_Boundary;

      procedure Require_Non_SPARK_Specs_Are_Documented_Boundaries is
         use Ada.Strings.Unbounded;

         Proof_Document : constant String :=
           Ada.Characters.Handling.To_Lower
             (Project_Tools.Files.Read_Raw_File
                (Project_Tools.Files.Join (Root, "docs/proof-coverage.md")));
         Source_Roots : constant Project_Tools.Files.Name_List :=
           [To_Unbounded_String ("common/src"),
            To_Unbounded_String ("common/generated")];
      begin
         for Source_Root of Source_Roots loop
            for Path of Project_Tools.Files.List_Tree (Project_Tools.Files.Join (Root, To_String (Source_Root))) loop
               declare
                  File_Path : constant String := To_String (Path);
               begin
                  if Project_Tools.Text.Ends_With (File_Path, ".ads")
                    and then not Project_Tools.Files.File_Contains (File_Path, "SPARK_Mode => On")
                  then
                     declare
                        Unit_Name : constant String := Proof_Unit_Name (File_Path);
                     begin
                        if not Is_Documented_Non_SPARK_Boundary (Unit_Name, Proof_Document) then
                           Project_Tools.Release_Checks.Fail
                             ("non-SPARK spec is missing from proof boundary docs: " & Unit_Name);
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end loop;
      end Require_Non_SPARK_Specs_Are_Documented_Boundaries;

      procedure Require_Package_File_List_Matches_Manifest is
         Files_Path : constant String := Project_Tools.Files.Join (Root, "generated/package-files.txt");
         Files      : constant String := Project_Tools.Files.Read_Raw_File (Files_Path);
         Manifest   : constant String :=
           Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"));

         procedure Check_Header is
            Header : constant String :=
              "posix-tools package manifest " & Posix_Tools.Version.Version_String;
            Count  : constant Natural := Count_Exact_Lines (Manifest, Header);
         begin
            if Count = 0 then
               Project_Tools.Release_Checks.Fail ("package manifest header missing or stale");
            elsif Count > 1 then
               Project_Tools.Release_Checks.Fail ("package manifest header is duplicated");
            end if;
         end Check_Header;

         procedure Check_File_List_Line (Relative_Path : String) is
            Expected_Line : constant String := Project_Tools.Release_Checks.Manifest_Line (Root, Relative_Path);
            Count         : constant Natural := Count_Exact_Lines (Manifest, Expected_Line);
         begin
            if Relative_Path = "" then
               null;
            elsif Count = 0 then
               Project_Tools.Release_Checks.Fail
                 ("package manifest missing generated file-list entry " & Relative_Path);
            elsif Count > 1 then
               Project_Tools.Release_Checks.Fail
                 ("package manifest duplicates generated file-list entry " & Relative_Path);
            end if;
         end Check_File_List_Line;

         File_Count         : Natural := 0;
         Manifest_Row_Count : constant Natural := Count_Nonempty_Lines (Manifest);
         Start              : Positive := Files'First;
      begin
         if Files = "" then
            Project_Tools.Release_Checks.Fail ("generated package file list is empty");
         end if;

         Check_Header;

         for I in Files'Range loop
            if Files (I) = Character'Val (10) then
               if I > Start then
                  Check_File_List_Line
                    (Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                       (Files (Start .. I - 1)));
                  File_Count := File_Count + 1;
               end if;

               Start := I + 1;
            end if;
         end loop;

         if Start <= Files'Last then
            Check_File_List_Line
              (Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                 (Files (Start .. Files'Last)));
            File_Count := File_Count + 1;
         end if;

         if Manifest_Row_Count = 0 then
            Project_Tools.Release_Checks.Fail ("package manifest is empty");
         elsif Manifest_Row_Count - 1 /= File_Count then
            Project_Tools.Release_Checks.Fail ("package manifest and generated file list have different entry counts");
         end if;
      end Require_Package_File_List_Matches_Manifest;

      procedure Require_Package_File_List_Covers_Fixtures is
         Files  : constant String :=
           Project_Tools.Files.Read_Raw_File
             (Project_Tools.Files.Join (Root, "generated/package-files.txt"));

         procedure Require_Fixture (Relative_Path : String) is
         begin
            if Count_Exact_Lines (Files, Relative_Path) = 0 then
               Project_Tools.Release_Checks.Fail
                 ("package file list missing test fixture " & Relative_Path);
            end if;
         end Require_Fixture;
      begin
         Require_Fixture ("fixtures/invalid-da-utf8.bin");
         Require_Fixture ("fixtures/reg-cat-0001.bin");
         Require_Fixture ("fixtures/reg-cat-first.bin");
         Require_Fixture ("fixtures/reg-cat-later.bin");
         Require_Fixture ("fixtures/reg-cat-second.bin");
         Require_Fixture ("fixtures/reg-end-of-options.txt");
         Require_Fixture ("fixtures/reg-head-counts.txt");
         Require_Fixture ("fixtures/reg-head-default-long.txt");
         Require_Fixture ("fixtures/reg-head-default-short.txt");
         Require_Fixture ("fixtures/reg-head-header-first.txt");
         Require_Fixture ("fixtures/reg-head-header-second.txt");
         Require_Fixture ("fixtures/reg-tail-byte-mode.bin");
         Require_Fixture ("fixtures/reg-tail-byte-spill.bin");
         Require_Fixture ("fixtures/reg-tail-compact.bin");
         Require_Fixture ("fixtures/reg-tail-head-first.txt");
         Require_Fixture ("fixtures/reg-tail-head-second.txt");
         Require_Fixture ("fixtures/reg-tail-line-mode.txt");
         Require_Fixture ("fixtures/reg-tail-plus.txt");
         Require_Fixture ("fixtures/reg-wc-bad-continuation.bin");
         Require_Fixture ("fixtures/reg-wc-default.txt");
         Require_Fixture ("fixtures/reg-wc-first.txt");
         Require_Fixture ("fixtures/reg-wc-invalid.bin");
         Require_Fixture ("fixtures/reg-wc-mixed-invalid.bin");
         Require_Fixture ("fixtures/reg-wc-out-of-range.bin");
         Require_Fixture ("fixtures/reg-wc-overlong.bin");
         Require_Fixture ("fixtures/reg-wc-second.txt");
         Require_Fixture ("fixtures/reg-wc-surrogate.bin");
         Require_Fixture ("fixtures/reg-wc-utf8.txt");
      end Require_Package_File_List_Covers_Fixtures;

      procedure Require_Package_File_List_Covers_Release_Metadata is
         Files : constant String :=
           Project_Tools.Files.Read_Raw_File
             (Project_Tools.Files.Join (Root, "generated/package-files.txt"));

         procedure Require_Packaged (Relative_Path : String) is
         begin
            if Count_Exact_Lines (Files, Relative_Path) = 0 then
               Project_Tools.Release_Checks.Fail
                 ("package file list missing release metadata " & Relative_Path);
            end if;
         end Require_Packaged;
      begin
         Require_Packaged (".github/workflows/ci.yml");
         Require_Packaged ("generated/command_inventory.csv");
         Require_Packaged ("generated/requirements.csv");
         Require_Packaged ("generated/regressions.csv");
         Require_Packaged ("generated/manual-index.md");
         Require_Packaged ("generated/package-files.txt");
      end Require_Package_File_List_Covers_Release_Metadata;

      procedure Require_Release_Checksums_Cover_Inventory is
         Path      : constant String := "generated/release-checksums.txt";
         Checksums : constant String := Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Path));
         Archive   : constant String := "dist/posix-tools-" & Posix_Tools.Version.Version_String & "-source.7z";

         function Checksum_Line (Label : String; Relative_Path : String) return String is
            Stable_Path : constant String := Project_Tools.Files.Join (Root, Relative_Path);
            Actual_Path : constant String :=
              (if Project_Tools.Files.File_Exists (Stable_Path) then Stable_Path
               elsif Project_Tools.Files.File_Exists (Stable_Path & ".exe") then Stable_Path & ".exe"
               else Stable_Path);
         begin
            return Label & " " & Relative_Path & " fnv1a64="
              & Project_Tools.Release_Checks.FNV1A64 (Actual_Path);
         end Checksum_Line;

         procedure Require_Header is
            Header : constant String :=
              "posix-tools release checksums " & Posix_Tools.Version.Version_String;
            Count  : constant Natural := Count_Exact_Lines (Checksums, Header);
         begin
            if Count = 0 then
               Project_Tools.Release_Checks.Fail ("release checksum header missing or stale");
            elsif Count > 1 then
               Project_Tools.Release_Checks.Fail ("release checksum header is duplicated");
            end if;
         end Require_Header;

         procedure Require_Checksum_Row (Label : String; Relative_Path : String) is
            Stable_Path : constant String := Project_Tools.Files.Join (Root, Relative_Path);
            Actual_Path : constant String :=
              (if Project_Tools.Files.File_Exists (Stable_Path) then Stable_Path
               elsif Project_Tools.Files.File_Exists (Stable_Path & ".exe") then Stable_Path & ".exe"
               else Stable_Path);
            Prefix      : constant String := Label & " " & Relative_Path & " fnv1a64=";
            Count       : Natural;
         begin
            if Project_Tools.Files.File_Exists (Actual_Path) then
               Count := Count_Exact_Lines (Checksums, Checksum_Line (Label, Relative_Path));

               if Count = 0 and then Count_Prefix_Lines (Checksums, Prefix) > 0 then
                  Project_Tools.Release_Checks.Fail ("release checksum entry is stale for " & Relative_Path);
               elsif Count = 0 then
                  Project_Tools.Release_Checks.Fail ("release checksum entry is missing for " & Relative_Path);
               elsif Count > 1 then
                  Project_Tools.Release_Checks.Fail ("release checksum entry is duplicated for " & Relative_Path);
               end if;
            else
               Count := Count_Prefix_Lines (Checksums, Prefix);

               if Count = 0 then
                  Project_Tools.Release_Checks.Fail ("release checksum entry is missing for " & Relative_Path);
               elsif Count > 1 then
                  Project_Tools.Release_Checks.Fail ("release checksum entry is duplicated for " & Relative_Path);
               end if;
            end if;
         end Require_Checksum_Row;

         Expected_Rows : constant Natural := Posix_Tools.Command_Inventory.Command_Count + 4;
      begin
         if Count_Nonempty_Lines (Checksums) /= Expected_Rows then
            Project_Tools.Release_Checks.Fail ("release checksum file has unexpected entry count");
         end if;

         Require_Header;
         Require_Checksum_Row ("manifest", "generated/package-manifest.txt");
         Require_Checksum_Row ("archive", Archive);

         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            Require_Checksum_Row
              ("executable",
               "tools/" & Posix_Tools.Command_Inventory.Executable (I)
               & "/bin/" & Posix_Tools.Command_Inventory.Executable (I));
         end loop;

         Require_Checksum_Row ("executable", "bin/posix-tools");
      end Require_Release_Checksums_Cover_Inventory;

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

      procedure Require_Crate_Metadata
        (Path         : String;
         Name         : String;
         Project_File : String) is
      begin
         Project_Tools.Release_Checks.Require_Text (Check, Path, "name = """ & Name & """");
         Require_Synchronized_Version (Path);
         Project_Tools.Release_Checks.Require_Text (Check, Path, "authors =");
         Project_Tools.Release_Checks.Require_Text (Check, Path, "maintainers =");
         Project_Tools.Release_Checks.Require_Text (Check, Path, "maintainers-logins =");
         Project_Tools.Release_Checks.Require_Text (Check, Path, "licenses = ""MIT""");
         Project_Tools.Release_Checks.Require_Text (Check, Path, "project-files = [""" & Project_File & """]");
         Project_Tools.Release_Checks.Require_Text (Check, Path, "[build-profiles]");
         Project_Tools.Release_Checks.Require_Text (Check, Path, """*"" = ""development""");
      end Require_Crate_Metadata;
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
      Project_Tools.Release_Checks.Require_Text (Check, "CHANGELOG.md", "28 POSIX-style utilities");
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
      Project_Tools.Release_Checks.Require_File (Check, "docs/ai.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/architecture.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/conformance.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/development.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/portability.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/proof-coverage.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/release-process.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/security.md");
      Project_Tools.Release_Checks.Require_File (Check, "docs/testing.md");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/release-process.md", "Node 24-compatible checkout action");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/development.md", "Node 24-compatible checkout action");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/portability.md", "Node 24-compatible checkout action");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Repository Map");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Package Map");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Dependency Rules");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Allowed Imports");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Prohibited Imports");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Project Invariants");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Command Workflow");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Test Requirements");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Localization Rules");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Styling Rules");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/ai.md", "Help, root headings, and human diagnostics may be styled");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/ai.md", "stderr terminal status for diagnostics");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Resource Policies");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Completion Criteria");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/ai.md", "## Rejected Architectures");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/ai.md", "Direct Hostkit use from command algorithms");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/ai.md", "Shell, Python, JavaScript, Make, CMake, or PowerShell project tooling");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`posix_tools_tests`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`test --suite <name>`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`test --category unit`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "`test --category integration`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "`test --category conformance`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "`test --category regression`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`build`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`check`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`format-check`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`docs`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`prove`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`package`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`release-check`");
      Project_Tools.Release_Checks.Require_Text (Check, "docs/testing.md", "`release`");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "docs/testing.md",
         "`posix_tools_tests format-check` scans maintained Ada, Alire/GPR, Markdown, CSV,");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/format_checks.adb", "function Has_Tab");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/format_checks.adb", "function Has_Trailing_Whitespace");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/format_checks.adb", "function Has_Multiple_Blank_Lines");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/format_checks.adb", "function Is_Checked_Text_File");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""test""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""check""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""release-check""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "elsif Command = ""release-check"" then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Run_Test_Selector_Smoke;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Run_Staged_Verification;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Run_Executable_Integration_Smoke;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "root executable help");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Executable & "" executable help""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "cp executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "date executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "dd executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "env executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "find executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "ln executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "mkdir executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "mv executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "printf executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "rm executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "rmdir executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "sort executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "tee executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test executable status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "touch executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "tr executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "uniq executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "xargs executable data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Generate_Release_Archive;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Generate_Release_Checksums;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Run_Proof_Checks;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""release""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "elsif Command = ""release"" then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Require_Clean_Source_Tree;");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "tests/src/posix_tools_tests.adb",
         "Require_Clean_Source_Tree;" & Character'Val (10) & "      Generate_Docs;");
      Require_Text_Before
        ("tests/src/posix_tools_tests.adb",
         "elsif Command = ""release"" then",
         "Ada.Text_IO.Put_Line (""release: completed by Ada project_tools driver"");",
         "release branch must run clean-tree-gated release work before completion");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "release: completed by Ada project_tools driver");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""build""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""conformance""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""format-check""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""docs""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""prove""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Command = ""package""");
      Require_Synchronized_Version ("alire.toml");
      Require_Synchronized_Version ("common/alire.toml");
      Require_Synchronized_Version ("tests/alire.toml");
      Require_Synchronized_Version ("common/src/posix_tools-version.ads");
      Require_Synchronized_Version ("CHANGELOG.md");
      Require_Synchronized_Version ("generated/manual-index.md");
      Require_Synchronized_Version ("generated/package-manifest.txt");
      Require_Synchronized_Version ("generated/release-checksums.txt");
      Require_Exact_Line
        ("alire.toml",
         "version = """ & Posix_Tools.Version.Version_String & """",
         "root manifest version");
      Require_Exact_Line
        ("common/alire.toml",
         "version = """ & Posix_Tools.Version.Version_String & """",
         "common manifest version");
      Require_Exact_Line
        ("tests/alire.toml",
         "version = """ & Posix_Tools.Version.Version_String & """",
         "tests manifest version");
      Require_Exact_Line
        ("common/src/posix_tools-version.ads",
         "   Version_String : constant String := """ & Posix_Tools.Version.Version_String & """;",
         "compiled version constant");
      Require_Exact_Line ("CHANGELOG.md", "## " & Posix_Tools.Version.Version_String, "changelog version");
      Require_Exact_Line
        ("generated/manual-index.md",
         "Version: " & Posix_Tools.Version.Version_String,
         "manual index version");
      Require_Exact_Line
        ("generated/package-manifest.txt",
         "posix-tools package manifest " & Posix_Tools.Version.Version_String,
         "package manifest version header");
      Require_Exact_Line
        ("generated/release-checksums.txt",
         "posix-tools release checksums " & Posix_Tools.Version.Version_String,
         "release checksum version header");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.ads", "type Count is range 0 .. 2 ** 63 - 1;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.ads", "Valid, Empty, Invalid_Syntax");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.ads", "Negative_Not_Permitted, Overflow");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Empty, Value => 0)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Negative_Not_Permitted, Value => 0)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Invalid_Syntax, Value => 0)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "return (Status => Overflow, Value => 0)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-numbers.adb", "if Value > (Count'Last - Digit_Value (Ch)) / 10");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse maximum count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse overflow");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-arguments-parsing.ads", "Unknown_Option");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-arguments-parsing.ads", "Missing_Argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Current = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Current = ""-""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Position.Offset < Current'Length");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.adb", "Position.Index < Argument_Count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-arguments-parsing.adb", "Posix_Tools.Option_Parsing.Decide_Short");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests-suite.adb", "property:option parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse grouped first option");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "option parser property seed 0x4F505453");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse attached option argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse separate option argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse end-of-options");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse lone hyphen operand");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse unknown option");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "parse missing option argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "function Basename");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "function Dirname");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "Collapse_Leading_Root");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-paths.adb", "Trim_Trailing_Slashes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-basename.adb", "Operand_Count > 2");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dirname.adb", "Operand_Count > 1");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:basename edge cases");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:dirname edge cases");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:basename dirname commands");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename command empty");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename non-ASCII suffix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename command backslash");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "dirname nested two leading slash");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "dirname command backslash");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "basename dirname command property seed 0xBA5ED123");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Context.Put (Context.Argument (I))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Context.Put ("" "")");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Conventional => False");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:echo data edge cases");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:echo output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "echo treats -- backslash and -n as data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "echo non-sole help preserves empty operand");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "echo property seed 0xEC400001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-true_command.adb", "Posix_Tools.Exit_Status.Success");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-false_command.adb", "Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-true_command.adb", "Conventional => False");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-false_command.adb", "Conventional => False");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:true extension edges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:false extension edges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:true false operands");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "true false operand property seed 0x7F00F15E");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-basename.adb", "Context.Argument (1) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dirname.adb", "Context.Argument (1) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "Context.Argument (1) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "File_Helpers.Copy_File");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "All_Ok := All_Ok and Ok");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-cat.adb", "Copy_File (Context, ""-"", Ok)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "if File_Name = ""-"" then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Copy_Standard_Input (Context, Ok)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Context.Put (To_String (Buffer, Last))");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-commands-file_helpers.adb",
         "Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat files");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat continues after missing file");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:cat byte preservation");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "seed 0x50540003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "PROPERTY-CAT-BYTES-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat output failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "cat continues after missing file");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "cat output failure has no read diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-CAT-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-CAT-0002");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-CAT-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-CAT-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-STDOUT-0004");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-TAIL-0004");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-WC-0005");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-ENV-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-VERBOSE-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-XARGS-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-ENV-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-VERBOSE-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-XARGS-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cp");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:date");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:dd");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:env");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:find");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:ln");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:mkdir");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:mv");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:printf");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:rm");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:rmdir");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:sort");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tee");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:test");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:touch");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tr");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:uniq");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:xargs");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector suite cp");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector suite xargs");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector suite root");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "test selector unknown suite");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "posix_tools_tests test --suite cp");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "`--suite cp`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "Unknown suite names fail with usage status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "posix_tools_tests test --suite cp");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Argument (Index) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Requested  : Posix_Tools.Numbers.Count := 10");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Argument (Index) = ""-n""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Argument (Index) (1 .. 2) = ""-n""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Parse_Nonnegative");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "missing option argument '-n'");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "invalid line count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Sources := (if First_File > Count then 1");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Context.Put_Line (""==> "" & Context.Argument (I)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Copy_Line_Prefix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Finish_Line_Prefix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head counts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head default limits");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:head prefix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:head standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head invalid count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head multiple file headers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head long default output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head prefix property seed 0x48454144");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head stdin property seed 0x4845AD15");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head zero output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head repeated -n uses last count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head leading plus count status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head missing count status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head preserves final partial line");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head multiple file headers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head repeated stdin is not rewound");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-HEAD-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-HEAD-0002");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-HEAD-0004");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-STREAMS-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Stop_Options : Boolean := False;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Argument (I) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Argument (I) = ""-L""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Argument (I) = ""-P""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Logical := True");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Logical := False");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Usable_Logical_Path");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Environment_Value (""PWD"")");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Path_Names_Current_Directory");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Try_Physical_Current_Directory");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:pwd options");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:pwd context fallbacks");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:pwd option precedence");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd -L output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd -P output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd last option wins");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd option precedence property seed 0x50574431");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd -P -L last option output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd relative PWD fallback output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd dot component fallback output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd dot-dot component fallback output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-tail_counts.ads", "type Count_Origin is (From_End, From_Start)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Current_Mode : Mode := Line_Mode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Requested  : Posix_Tools.Numbers.Count := 10");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-n""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-c""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-f""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""-F""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) = ""--follow""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) (2) = 'n'");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Context.Argument (Index) (2) = 'c'");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-tail_counts.adb",
         "Text (Text'First) = '+'");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Posix_Tools.Tail_Counts.Parse_Count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "missing option argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "invalid count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "procedure Copy");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Copy_Line_Suffix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Copy_Lines_From");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-commands-tail.adb",
         "Context.Put_Line (""==> "" & Context.Argument (File_Index)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail byte mode edges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail compact counts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail follow live");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail invalid count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail line mode edges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail multiple file headers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail plus origin");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:tail byte suffix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:tail standard input bytes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:tail line suffix");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail default ten lines from end output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -c property seed 0x5441494C");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail stdin -c property seed 0x54414953");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -n property seed 0x5441494E");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -c2 compact output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -c+4 compact output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -f live status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail --follow live status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -F reopen status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail later -c overrides earlier -n");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail later -n overrides earlier -c");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail -n +2 output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail lone plus count status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail missing -c count status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail final partial line output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail multiple file headers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail repeated stdin is not rewound");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0002");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0005");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0006");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Context.Argument (First_File) = ""--""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Show_L := True");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Show_W := True");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Show_C := True");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "when 'm' => Show_M := True");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Posix_Tools.Wc_Fields.Needs_Text_Decoding");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Total.Lines := Total.Lines + C.Lines");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Print_Counts (Context, Total, ""total""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Text_Invalid (State)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Increment (Self.Current.Bytes)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Increment (Self.Current.Lines)");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-streams-counting.adb",
         "Increment (Self.Current.Characters)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Increment (Self.Current.Words)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-streams-counting.adb", "Posix_Tools.Text.UTF_8.Decode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Byte in 16#C2# .. 16#DF#");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Self.Accumulator in 16#D800# .. 16#DFFF#");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests-suite.adb", "streams:byte counting");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests-suite.adb", "streams:utf-8 counting");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc multiple files");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc default and mixed text");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc text counts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc invalid UTF-8");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc malformed UTF-8");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc byte count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc standard input bytes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc line count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "property:wc standard input lines");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc default field order");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -c raw output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -c property seed 0x5EEDC0DE");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc stdin -c property seed 0x57C00001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -l raw output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -l property seed 0x1F1E5EED");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc stdin -l property seed 0x57C0000A");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc multiple file totals");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc repeated stdin is not rewound");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc -m output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc mixed invalid suppresses output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc overlong suppresses output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc surrogate suppresses output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0002");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0006");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:end-of-options");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head skips -- after count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail skips -- after count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc skips -- after option");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-OPTIONS-0001");
      Project_Tools.Release_Checks.Require_Text (Check, "common/alire.toml", "hostkit =");
      Project_Tools.Release_Checks.Require_Text (Check, "common/alire.toml", "messages =");
      Project_Tools.Release_Checks.Require_Text (Check, "common/alire.toml", "terminal_styles =");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/alire.toml", "hostkit = { path = ""../../hostkit"" }");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/alire.toml", "messages = { path = ""../../messages"" }");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/alire.toml", "terminal_styles = { path = ""../../terminal_styles"" }");
      Require_Crate_Metadata ("common/alire.toml", "posix_tools_common", "posix_tools_common.gpr");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.help.usage = Brug");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "es.posix_tools.help.usage = Uso");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.diagnostic.option.unknown");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "es.posix_tools.diagnostic.option.unknown");
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
        (Check, "common/src/posix_tools-localization.adb", "with Messages.Runtime;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-localization.adb", "Messages.Runtime.Render");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-localization.adb", "Messages.Arguments.Set");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-localization.adb", "Messages.Result.Output_Text");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-help.adb", "posix_tools.help.usage");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-help.adb", "posix_tools.help.options");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-help.adb", "posix_tools.common.option.help");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-help.adb", "posix_tools.common.option.version");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-helpers.adb", "Localized_Usage_Message");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-helpers.adb", "function Escape_Untrusted");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-helpers.adb", "posix_tools.diagnostic.option.unknown");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-helpers.adb", "posix_tools.diagnostic.extra_operand");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-helpers.adb", "posix_tools.diagnostic.count.invalid");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "posix_tools.diagnostic.file.read_failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "posix_tools.diagnostic.resource.count_too_large");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "posix_tools.diagnostic.text.invalid_utf8");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "locale:help");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "locale:diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "regression:REG-DIAG-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-DIAG-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "REG-DIAG-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "unknown locale no message-key leak");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "Danish extra operand diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "Danish count too large diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "with Terminal_Styles;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.ads", "type Style_Mode is (Automatic, Always, Never)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "Terminal_Styles.Color_Auto");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "Terminal_Styles.Color_Always");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "Terminal_Styles.Color_Never");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "Destination_Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-presentation.adb", "Terminal_Styles.Role_Error");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-helpers.adb", "Presentation.Diagnostic");
      Forbid_Text
        ("common/src/posix_tools-help.adb",
         "with Terminal_Styles",
         "help rendering must use Posix_Tools.Presentation instead of terminal_styles directly");
      Forbid_Text
        ("common/src/posix_tools-commands-root.adb",
         "with Terminal_Styles",
         "root rendering must use Posix_Tools.Presentation instead of terminal_styles directly");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "Set_Style_Mode (Posix_Tools.Presentation.Never)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "Set_Style_Mode (Posix_Tools.Presentation.Always)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "Set_Style_Mode (Posix_Tools.Presentation.Automatic)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-terminals.adb", "with Hostkit.Descriptors;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-terminals.adb", "Hostkit.Descriptors.Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-terminals.adb", "Hostkit.Descriptors.Terminal_Name");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-terminals.adb", "Hostkit.Descriptors.Standard_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-terminals.adb", "Hostkit.Descriptors.Standard_Error");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-terminals.adb",
         "Hostkit.Host",
         "terminal adapter must use hostkit descriptors for standard stream terminal checks");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Terminals.Standard_Output_Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Terminals.Standard_Error_Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/test_contexts.adb", "return Self.Output_Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/test_contexts.adb", "return Self.Error_Is_Terminal");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Max_Identity_Output_Bytes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Hostkit.Process.Locate");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Hostkit.Process.Run_Captured");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "with Hostkit.Descriptors;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Hostkit.Descriptors.Open_File");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Hostkit.Descriptors.Read");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Capture_Leaf");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Timeout_Ms  => 2000");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Output = Excessive_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Error = Excessive_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Expected_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Is_Wrong_Version_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Output = Expected_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "Hostkit.Fs.Is_Executable");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-executables.adb", "return ""shadowed""");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-executables.adb",
         "stdout.txt",
         "identity verification must not use a fixed stdout capture leaf");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-executables.adb",
         "stderr.txt",
         "identity verification must not use a fixed stderr capture leaf");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-executables.adb",
         "Ada.Text_IO",
         "identity verification must read captured subprocess output through hostkit descriptors");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "Host_Adapters.Executables.Locate");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "Host_Adapters.Executables.Verify_Identity");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Run_Staged_Verification;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Verify_Identity_At_Path");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:root verify");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "locale:root verify statuses");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "Contains_Executable (Context.Argument (2))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "Render_Command_Help (Context, Context.Argument (2))");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-helpers.adb", "Render_Command_Help (Context, Context.Command_Name)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "root command help must reuse command metadata");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "function Root_Status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "if Context.Output_Failed then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "return Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-root.adb", "exit when Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "root output failure status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-ROOT-0002");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-basename.adb", "Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dirname.adb", "Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-basename.adb", "Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dirname.adb", "Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-echo.adb", "Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-pwd.adb", "Posix_Tools.Exit_Status.Operational_Failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:simple output failures");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "simple output failure diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-STDOUT-0001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Stop := Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Ok := not Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "if Context.Output_Failed then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "if Context.Output_Failed then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "exit when Context.Output_Failed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat output failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head output failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail output failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc output failure");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "cat output failure has no read diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head output failure diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail output failure diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "wc output failure diagnostic");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-CAT-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-HEAD-0003");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-TAIL-0004");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0005");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "en.posix_tools.root.status.shadowed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "da.posix_tools.root.status.shadowed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/messages/posix_tools.catalog", "es.posix_tools.root.status.shadowed");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-environment.adb", "with Ada.Environment_Variables;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system-directories.adb", "with Ada.Directories;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system-io.adb", "with Hostkit.Descriptors;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system-paths.adb", "Hostkit.Metadata.Same_File");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.ads", "type File_Time is private");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.ads", "Copy_Modification_Time");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.ads", "File_Time_Of");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-file_system.ads", "Set_Modification_Time");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-host_adapters-file_system-times.adb",
         "GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp");
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
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-temporary_storage.adb", "Open_Write_Exclusive");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-temporary_storage.adb", "Spill_Leaf");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-temporary_storage.ads",
         "Ada.Streams.Stream_IO",
         "production temporary storage adapter must use hostkit descriptors");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-temporary_storage.adb",
         "Ada.Streams.Stream_IO",
         "production temporary storage adapter must use hostkit descriptors");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-temporary_storage.adb",
         "spill.bin",
         "production temporary storage filenames must not use a fixed spill leaf");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-arguments.adb", "with Ada.Command_Line;");
      Forbid_Text
        ("common/src/posix_tools-arguments.adb",
         "Ada.Command_Line",
         "argument value type must not capture process command-line state");
      Forbid_Text
        ("common/src/posix_tools-localization.adb",
         "Ada.Directories",
         "localization must use the project filesystem adapter for catalog path probing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-localization.adb", "with Posix_Tools.Host_Adapters.File_System;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "pwd stale PWD fallback output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.ads", "Try_Physical_Current_Directory");
      Forbid_Text
        ("common/src/posix_tools-commands-pwd.adb",
         "when others",
         "pwd must report expected current-directory failures through context results");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-streams.adb", "with Hostkit.Descriptors;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-streams.adb", "Hostkit.Descriptors.Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-streams.adb", "Hostkit.Descriptors.Standard_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-streams.adb", "Hostkit.Descriptors.Standard_Error");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-streams.adb", "Transfer_Interrupted");
      Forbid_Text
        ("common/src/posix_tools-host_adapters-streams.adb",
         "Ada.Text_IO",
         "standard stream adapter must use hostkit descriptors for byte-oriented process streams");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "build common crate");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools root");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.version");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.command_inventory");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.numbers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.paths");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.utf_8");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.classification");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.whitespace_data");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.streams.counting");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.counts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.tail_rings");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.tail_counts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.wc_fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.exit_status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.commands.results");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.commands");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.streams");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.escaping");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.checksum_lines");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.checksums");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.cut_fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.dd_conversions");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.duration_fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.file_magic_fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.line_breaks");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.byte_classes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.matching");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.nice_fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.base_parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.suffixes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.tab_stops");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.logical_paths");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.portable_paths");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.test_operators");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.hex_digests");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.sort_modifiers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.paste_delimiters");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.printf_escapes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.seq_formats");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.find_expressions");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.od_formats");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.signal_names");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.nl_fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.decimal_parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.file_modes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.file_modes level 2");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.numeric_images");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.option_parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.octal_modes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.octal_parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.owner_groups");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.time_fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.touch_fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "proof target posix_tools.text.xargs_fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "--prover=z3");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/development.md", "Selected GNATprove targets");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/development.md", "docs/proof-coverage.md");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Cut_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.DD_Conversions");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Duration_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Checksum_Lines");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Checksums");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.File_Magic_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Decimal_Parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Base_Parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Suffixes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Tab_Stops");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Logical_Paths");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Portable_Paths");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Test_Operators");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Hex_Digests");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Sort_Modifiers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Paste_Delimiters");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Nice_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Xargs_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Find_Expressions");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.OD_Formats");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Signal_Names");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.NL_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Count_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Parsed_Find_Count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Parse_Find_Count");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Age_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Ownership_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Missing_Owner_Name_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Parse_Type_Filter");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Find_Special_File_Class");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-find_expressions.ads", "Type_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.File_Modes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Has_Mode_Bit");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Has_Any_Mode_Bit");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Has_All_Mode_Bits");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Set_Mode_Bit");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Clear_Mode_Bit");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Clear_Mode_Mask");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Set_Mode_Mask");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Parsed_Permission_Mode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Parse_Permission_Mode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Parse_Find_Permission_Mode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Symbolic_Permission_Bits");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Apply_Symbolic_Permission_Operation");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Apply_Symbolic_Mode");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Symbolic_Who_Mask");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-file_modes.ads", "Permission_Matches");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-touch_fields.ads", "Normalize_ISO_Date_Time");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-arguments-parsing.ads", "Missing_Argument");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-signals.ads", "Unknown_Disposition");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Numeric_Images");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Seq_Formats");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Tail_Counts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Option_Parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.ads", "Cursor_Progresses");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.ads", "Source_Is_Consistent");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-option_parsing.ads", "Status_Is_Consistent");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-xargs_parsing.adb", "Text.Byte_Classes.Is_Xargs_Blank");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-host_adapters-host.ads", "Last <= Groups'Length");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.ads", "Last <= Groups'Length");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Octal_Parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Octal_Modes");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Time_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Text.Touch_Fields");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-line_breaks.ads", "Line_Number_Through");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Posix_Tools.Arguments.Parsing");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "host adapters");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "Ada.Containers.Indefinite_Vectors");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "docs/proof-coverage.md");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "metadata checks keep that document synchronized");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/proof-coverage.md", "dispatcher-only boundary");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "tail ring arithmetic tests");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/testing.md", "wc field arithmetic tests");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/release-process.md", "posix_tools_tests prove");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/build_checks.adb", "build root crate");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/build_checks.adb", "build tests crate");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "tests/src/build_checks.adb",
         "for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "tests/src/build_checks.adb",
         """build "" & Posix_Tools.Command_Inventory.Executable (I)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "procedure Run_Staged_Verification");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Verify_Identity_At_Path");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", """posix-tools"", Built_Root_Path");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Built_Root_Path, ""0.0.0""");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "Status /= ""wrong version""");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "tests/src/posix_tools_tests.adb",
         "Executable : constant String := Posix_Tools.Command_Inventory.Executable (I)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/posix_tools_tests.adb", "staged verification checks passed");
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
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "with Posix_Tools.Host_Adapters.Environment;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "with Posix_Tools.Host_Adapters.File_System;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "with Posix_Tools.Host_Adapters.Streams;");
      Forbid_Text
        ("common/src/posix_tools-commands-dispatcher.adb",
         "procedure Run_",
         "command dispatcher must not regain command-local algorithms");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dispatcher.adb", "Posix_Tools.Commands.Find.Run");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dispatcher.adb", "Posix_Tools.Commands.Sort.Run");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dispatcher.adb", "Posix_Tools.Commands.Test_Command.Run");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-dispatcher.adb", "Posix_Tools.Commands.Uniq.Run");
      Forbid_Text
        ("common/src/posix_tools-commands-find.adb",
         "with Hostkit.Fs",
         "find command algorithm must use the project filesystem adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-find.adb",
         "with Hostkit.Metadata",
         "find command algorithm must use the project filesystem adapter for metadata");
      Forbid_Text
        ("common/src/posix_tools-commands-find.adb",
         "with Hostkit.Signals",
         "find command algorithm must use the project signals adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-find.adb",
         "with Ada.Directories",
         "find command algorithm must use the project filesystem adapter");
      Forbid_Text
        ("common/src/posix_tools-commands-find.adb",
         "GNAT.OS_Lib",
         "find command algorithm must use the project filesystem adapter for timestamps");
      Forbid_Text
        ("common/src/posix_tools-commands-dispatcher.adb",
         "with Hostkit.Fs",
         "command dispatcher must not depend on hostkit directly");
      Forbid_Text
        ("common/src/posix_tools-commands-dispatcher.adb",
         "with Hostkit.Metadata",
         "command dispatcher must not depend on hostkit metadata");
      Forbid_Text
        ("common/src/posix_tools-commands-dispatcher.adb",
         "with Hostkit.Signals",
         "command dispatcher must not depend on hostkit signals");
      Forbid_Text
        ("common/src/posix_tools-commands-dispatcher.adb",
         "with Ada.Directories",
         "command dispatcher must not use filesystem algorithms");
      Forbid_Text
        ("common/src/posix_tools-commands-dispatcher.adb",
         "GNAT.OS_Lib",
         "command dispatcher must not use OS timestamp helpers");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-find.adb", "with Posix_Tools.Host_Adapters.File_System;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tee.adb", "with Posix_Tools.Host_Adapters.Signals;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "with Posix_Tools.Host_Adapters.Terminals;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Environment.Value");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.File_System.Physical_Current_Directory");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-commands-contexts.adb",
         "Host_Adapters.File_System.Try_Physical_Current_Directory");
      Project_Tools.Release_Checks.Require_Text
        (Check,
         "common/src/posix_tools-commands-contexts.adb",
         "Host_Adapters.File_System.Path_Names_Current_Directory");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Streams.Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Streams.Try_Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Streams.Write_Standard_Output");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Streams.Write_Standard_Error_Line");
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
      Project_Tools.Release_Checks.Require_Text (Check, "tests/alire.toml", "executables = [""posix_tools_tests""]");
      Require_Crate_Metadata ("tests/alire.toml", "posix_tools_tests", "posix_tools_tests.gpr");
      Forbid_Text
        ("tests/alire.toml",
         "posix_tools =",
         "tests manifest must not depend on root binary crate");
      Forbid_Text
        ("tests/alire.toml",
         "hostkit =",
         "tests manifest must use common adapters instead of depending on hostkit directly");
      Forbid_Text
        ("tests/alire.toml",
         "messages =",
         "tests manifest must use common localization instead of depending on messages directly");
      Forbid_Text
        ("tests/alire.toml",
         "terminal_styles =",
         "tests manifest must use common presentation instead of depending on terminal_styles directly");
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
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "if File_Name = ""-"" then");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Context.Try_Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.ads", "function Try_Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-contexts.adb", "Host_Adapters.Streams.Try_Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/test_contexts.ads", "function Try_Read_Standard_Input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:cat standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:head standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc standard input");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-STDIN-0001");
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
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "procedure For_Each_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "Action (Context, Buffer, Last)");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-file_helpers.adb", "For_Each_File_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "File_Helpers.For_Each_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "Action => Retain_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "Action => Emit_From_Start");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "File_Helpers.For_Each_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-wc.adb", "Action => Count_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:tail byte mode edges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests-suite_entries.adb", "command:wc default and mixed text");
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
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "Requested  : Posix_Tools.Numbers.Count := 10;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-head.adb", "First_File : Positive := 1;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-tail_counts.ads", "type Count_Origin is (From_End, From_Start);");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail.adb", "Origin     : Count_Origin := From_End;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "Filled : Natural := 0;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "Next   : Ada.Streams.Stream_Element_Offset := Ring'First;");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "procedure Retain_Chunk");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-commands-tail_bytes.adb", "procedure Emit_From_Start");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "head output failure status");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/command_tests.adb", "tail output failure status");
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
         Require_Crate_Metadata
           (Posix_Tools.Command_Inventory.Manifest_Path (I),
            Posix_Tools.Command_Inventory.Crate (I),
            "posix_tools_" & Posix_Tools.Command_Inventory.Executable (I) & ".gpr");
         Require_Synchronized_Version (Posix_Tools.Command_Inventory.Manifest_Path (I));
         Require_Exact_Line
           (Posix_Tools.Command_Inventory.Manifest_Path (I),
            "version = """ & Posix_Tools.Version.Version_String & """",
            Posix_Tools.Command_Inventory.Executable (I) & " manifest version");
         Project_Tools.Release_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "[[depends-on]]");
         Project_Tools.Release_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "posix_tools_common =");
         Project_Tools.Release_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "posix_tools_common = ""*""");
         Project_Tools.Release_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), "[[pins]]");
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
         Project_Tools.Release_Checks.Require_Text
           (Check, Posix_Tools.Command_Inventory.Manifest_Path (I), """*"" = ""development""");
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
         end;
      end loop;
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "COMMAND-IMPORT-BOUNDARY-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "POSIX-WC-UTF8-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "TEXT-UTF8-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "TEXT-WHITESPACE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Expected_Continuations");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Minimum_Code_Point");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Self.Accumulator < Self.Minimum_Code_Point");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Self.Accumulator in 16#D800# .. 16#DFFF#");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Self.Accumulator > 16#10FFFF#");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-utf_8.adb", "Status := Invalid");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "incomplete UTF-8");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "surrogate UTF-8 rejected");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "out-of-range UTF-8 rejected");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "decoder rejects overlong starter");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/regressions.csv", "REG-WC-0004");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/generated/posix_tools-text-whitespace_data.ads", "Unicode_Version");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/generated/posix_tools-text-whitespace_data.ads", "Unicode License v3");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/generated/posix_tools-text-whitespace_data.ads", "PropList.txt White_Space property");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/generated/posix_tools-text-whitespace_data.ads", "White_Space_Ranges");
      Project_Tools.Release_Checks.Require_Text
        (Check, "common/src/posix_tools-text-classification.adb", "Whitespace_Data.Is_Whitespace");
      Project_Tools.Release_Checks.Require_Text
        (Check, "tests/src/basic_tests.adb", "classification includes range midpoint");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "PRESENTATION-STYLES-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "help root headings and diagnostics");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "HOST-ADAPTER-TERMINAL-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "standard-error terminal status");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "HOST-ADAPTER-FILE-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "NONPOSIX-WC-LINE-LENGTH-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "VERSION-GENERATION-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "VERSION-LOCALE-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "IDENTITY-LOCALE-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "POSIX-TAIL-COMPACT-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "STATE-HEAD-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "STATE-TAIL-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-STDIN-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-STDOUT-FAIL-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-STDOUT-FAIL-002");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "CONTEXT-CHUNK-ITERATION-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "ROOT-LIST-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "PROPERTY-ROOT-LIST-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "ROOT-LIST-LOCALE-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "ROOT-VERIFY-LOCALE-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "PROPERTY-ROOT-HELP-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "PROPERTY-ROOT-PATHS-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "PROPERTY-ROOT-VERIFY-001");
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
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "stderr diagnostic styling policy");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "DOCS-MANPAGES-001");
      Project_Tools.Release_Checks.Require_Text (Check, "generated/requirements.csv", "DOCS-MANPAGES-CURRENT-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "DOCS-COMMAND-INDEX-CURRENT-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "DOCS-CHANGELOG-CURRENT-001");
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
        (Check, "generated/requirements.csv", "MANIFEST-GRAPH-005");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "MANIFEST-CRATE-METADATA-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "LOCAL-PINS-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "PORTABILITY-WINDOWS-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "TOOLING-COMMAND-SURFACE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "FORMAL-PROOF-CI-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "STAGED-VERIFY-ROOT-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "EXTERNAL-COMMAND-SCOPE-001");
      Forbid_Text
        ("generated/command_inventory.csv",
         "awk,posix_tools_awk",
         "awk is implemented in a separate project and must not be in this repository inventory");
      Forbid_Text
        ("generated/command_inventory.csv",
         "grep,posix_tools_grep",
         "grep is implemented in a separate project and must not be in this repository inventory");
      Forbid_Text
        ("generated/command_inventory.csv",
         "sed,posix_tools_sed",
         "sed is implemented in a separate project and must not be in this repository inventory");
      if Project_Tools.Files.Directory_Exists (Project_Tools.Files.Join (Root, "tools/awk")) then
         Project_Tools.Release_Checks.Fail ("awk command subcrate must not be present in posix_tools");
      elsif Project_Tools.Files.Directory_Exists (Project_Tools.Files.Join (Root, "tools/grep")) then
         Project_Tools.Release_Checks.Fail ("grep command subcrate must not be present in posix_tools");
      elsif Project_Tools.Files.Directory_Exists (Project_Tools.Files.Join (Root, "tools/sed")) then
         Project_Tools.Release_Checks.Fail ("sed command subcrate must not be present in posix_tools");
      end if;
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "ubuntu-latest");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "macos-15-intel");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "windows-latest");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "pull_request:");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "workflow_dispatch:");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "contents: read");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "timeout-minutes: 60");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "fail-fast: false");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "actions/checkout@v7");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: posix_tools");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/hostkit");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: hostkit");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/messages");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: messages");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/i18n");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: i18n");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/awklib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: awklib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/regexp");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: regexp");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/httpclient");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: httpclient");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/zlib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: zlib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/tarlib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: tarlib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/cryptolib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: cryptolib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/ssllib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: ssllib");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "repository: bracke/truststores");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: truststores");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "repository: bracke/terminal_styles");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: terminal_styles");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "repository: bracke/project_tools");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "path: project_tools");
      Forbid_Text
        (".github/workflows/ci.yml", "actions/checkout@v4", "CI workflow must use Node 24 compatible checkout");
      Forbid_Text
        (".github/workflows/ci.yml", "actions/setup-node@v4", "CI workflow must not pin Node 20 setup actions");
      Forbid_Text
        (".github/workflows/ci.yml", "actions/cache/restore@v4", "CI workflow must not pin Node 20 cache actions");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "alire-project/setup-alire@v6");
      Forbid_Text
        (".github/workflows/ci.yml",
         "alire-project/setup-alire@v6.0.0",
         "CI workflow must use setup-alire v6 branch with Node 24 internals");
      Forbid_Text
        (".github/workflows/ci.yml", "alire-project/setup-alire@v5", "CI workflow must use current setup-alire");
      Project_Tools.Release_Checks.Require_Text (Check, ".github/workflows/ci.yml", "alr -n build");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "working-directory: posix_tools/tests");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "posix_tools_tests.exe");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "release-check");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "alr -n install gnatprove");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "GITHUB_PATH");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "cygpath -w");
      Project_Tools.Release_Checks.Require_Text
        (Check, ".github/workflows/ci.yml", "gnatprove");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "CI-WORKFLOW-GATE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "Node 24 compatible checkout actions");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "sibling dependency checkouts");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "Node 24 compatible setup-alire branch");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "PACKAGE-INVENTORY-COMPLETE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "PACKAGE-MANIFEST-COVERAGE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "INTEGRATION-EXECUTABLE-SMOKE-001");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "RELEASE-ARCHIVE-001");
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
        (Check, "generated/release-checksums.txt", "archive dist/posix-tools-");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/release-checksums.txt", "executable bin/posix-tools fnv1a64=");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "platform-aware executable artifact lookup");
      Require_All_SPARK_Specs_Are_Proof_Targets_And_Documented;
      Require_Non_SPARK_Specs_Are_Documented_Boundaries;
      Require_Release_Checksums_Cover_Inventory;
      Project_Tools.Release_Checks.Require_Text (Check, ".gitignore", "/dist/");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "README.md");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "generated/package-files.txt");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "alire.toml");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "common/alire.toml");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "common/posix_tools_proof.gpr");
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
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
         Root,
         "common/messages/posix_tools.catalog");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"), Root, "tests/alire.toml");
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
         Root,
         "tests/src/posix_tools_tests.adb");
      Require_Package_File_List_Matches_Manifest;
      Require_Package_File_List_Covers_Fixtures;
      Require_Package_File_List_Covers_Release_Metadata;
      Project_Tools.Release_Checks.Require_Manifest_Entry
        (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
         Root,
         "tests/src/test_contexts.ads");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Project_Tools.Release_Checks.Require_Manifest_Entry
           (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
            Root,
            Posix_Tools.Command_Inventory.Manifest_Path (I));
         Project_Tools.Release_Checks.Require_Manifest_Entry
           (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
            Root,
            Posix_Tools.Command_Inventory.Project_File_Path (I));
         Project_Tools.Release_Checks.Require_Manifest_Entry
           (Project_Tools.Files.Join (Root, "generated/package-manifest.txt"),
            Root,
            Posix_Tools.Command_Inventory.Documentation_Path (I));
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
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Project_Tools.Release_Checks.Require_Text
           (Check, "README.md", "- `" & Posix_Tools.Command_Inventory.Executable (I) & "`");
      end loop;
      Project_Tools.Release_Checks.Require_Text (Check, "README.md", "- `posix-tools`");
      Project_Tools.Release_Checks.Require_Text
        (Check, "README.md", "`awk`, `grep`, and `sed` are not implemented in this repository");
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "DOCS-README-INVENTORY-001");
      Ada.Text_IO.Put_Line ("metadata checks passed");
   end Run_Metadata_Checks;

   procedure Generate_Docs is
      use Ada.Strings.Unbounded;
      Content : Unbounded_String;
      Base    : constant String := Root;
      Man_Dir : constant String := Project_Tools.Files.Join (Base, "generated/man");

      function Boolean_Text (Value : Boolean) return String is
      begin
         if Value then
            return "true";
         else
            return "false";
         end if;
      end Boolean_Text;

      function Render_Command_Inventory return String is
         Inventory_Content : Unbounded_String;
      begin
         Append
           (Inventory_Content,
            "executable,crate,package,manifest_path,project_file_path,documentation_path,"
            & "release_included,posix_status,help,version,identity"
            & Character'Val (10));

         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            Append
              (Inventory_Content,
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

         return To_String (Inventory_Content);
      end Render_Command_Inventory;

      function Render_Command_Reference_Index return String is
         Index_Content : Unbounded_String;
         Root_Inserted : Boolean := False;
      begin
         Append (Index_Content, "# Command References" & Character'Val (10) & Character'Val (10));
         Append (Index_Content, "V1 command references:" & Character'Val (10) & Character'Val (10));

         for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            if not Root_Inserted
              and then "posix-tools" < Posix_Tools.Command_Inventory.Executable (I)
            then
               Append (Index_Content, "- [posix-tools](posix-tools.md)" & Character'Val (10));
               Root_Inserted := True;
            end if;

            Append
              (Index_Content,
               "- [" & Posix_Tools.Command_Inventory.Executable (I) & "]("
               & Posix_Tools.Command_Inventory.Executable (I) & ".md)"
               & Character'Val (10));
         end loop;

         if not Root_Inserted then
            Append (Index_Content, "- [posix-tools](posix-tools.md)" & Character'Val (10));
         end if;

         return To_String (Index_Content);
      end Render_Command_Reference_Index;

      procedure Generate_Command_Inventory is
      begin
         Project_Tools.Files.Write_Raw_File
           (Project_Tools.Files.Join (Base, "generated/command_inventory.csv"),
            Render_Command_Inventory);
      end Generate_Command_Inventory;

      procedure Generate_Manpage (Index : Positive) is
         Command : constant String := Posix_Tools.Command_Inventory.Executable (Index);
      begin
         Project_Tools.Files.Write_Raw_File
           (Project_Tools.Files.Join (Man_Dir, Command & ".1"), Command_Manpage (Index));
      end Generate_Manpage;

      procedure Generate_Root_Manpage is
      begin
         Project_Tools.Files.Write_Raw_File
           (Project_Tools.Files.Join (Man_Dir, "posix-tools.1"), Root_Manpage);
      end Generate_Root_Manpage;
   begin
      if not Ada.Directories.Exists (Man_Dir) then
         Ada.Directories.Create_Directory (Man_Dir);
      end if;

      Generate_Command_Inventory;
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
      Append (Content, Character'Val (10));

      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Base, "generated/manual-index.md"), To_String (Content));
      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Base, "docs/commands/index.md"), Render_Command_Reference_Index);
      Ada.Text_IO.Put_Line ("docs/commands/index.md");
      Ada.Text_IO.Put_Line ("generated/command_inventory.csv");
      Ada.Text_IO.Put_Line ("generated/manual-index.md");
      Ada.Text_IO.Put_Line ("generated/man/*.1");
   end Generate_Docs;

   procedure Generate_Package_Manifest is
      use Ada.Strings.Unbounded;
      Content : Unbounded_String;
      Files   : Unbounded_String;
      Base    : constant String := Root;

      procedure Add_Entry (Relative_Path : String) is
      begin
         Append (Files, Relative_Path & Character'Val (10));
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
      declare
         procedure Append_Entries is new Package_Entries (Add_Entry);
      begin
         Append_Entries;
      end;

      Append (Files, "generated/package-files.txt" & Character'Val (10));
      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Base, "generated/package-files.txt"), To_String (Files));
      Ada.Text_IO.Put_Line ("generated/package-files.txt");
      Append
        (Content,
         Project_Tools.Release_Checks.Manifest_Line (Base, "generated/package-files.txt")
         & Character'Val (10));
      Project_Tools.Files.Write_Raw_File
        (Project_Tools.Files.Join (Base, "generated/package-manifest.txt"), To_String (Content));
      Ada.Text_IO.Put_Line ("generated/package-manifest.txt");
   end Generate_Package_Manifest;

   function Release_Archive_Path return String is
   begin
      return "dist/posix-tools-" & Posix_Tools.Version.Version_String & "-source.7z";
   end Release_Archive_Path;

   procedure Generate_Release_Archive is
      Archive  : constant String := Release_Archive_Path;
      Seven_Z  : constant String := Project_Tools.Processes.Locate_Command ("7z");
      Seven_Zz : constant String := Project_Tools.Processes.Locate_Command ("7zz");
      Archiver : constant String := (if Seven_Z /= "" then Seven_Z else Seven_Zz);
      Output   : Ada.Strings.Unbounded.Unbounded_String;
      Status   : Integer;
   begin
      if Archiver = "" then
         Project_Tools.Release_Checks.Fail ("7z-compatible command not found for release archive generation");
      end if;

      if not Project_Tools.Files.Directory_Exists (Project_Tools.Files.Join (Root, "dist")) then
         Ada.Directories.Create_Directory (Project_Tools.Files.Join (Root, "dist"));
      end if;

      Project_Tools.Files.Delete_File_If_Present (Project_Tools.Files.Join (Root, Archive));
      Status :=
        Project_Tools.Processes.Run_Status
           (Label   => "create release archive",
            Dir     => Root,
            Program => Archiver,
            Args    => Project_Tools.Processes.Arguments
              ([Project_Tools.Processes.Argument ("a"),
                Project_Tools.Processes.Argument ("-t7z"),
                Project_Tools.Processes.Argument ("-mx=9"),
                Project_Tools.Processes.Argument ("-mmt=off"),
                Project_Tools.Processes.Argument ("-mtm=off"),
                Project_Tools.Processes.Argument (Archive),
                Project_Tools.Processes.Argument ("@generated/package-files.txt")]),
            Output  => Output,
            Quiet   => True);

      if Status /= 0 then
         Project_Tools.Release_Checks.Fail
           ("release archive generation failed with status" & Integer'Image (Status));
      elsif not Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Archive)) then
         Project_Tools.Release_Checks.Fail ("release archive was not created");
      end if;

      Status :=
        Project_Tools.Processes.Run_Status
           (Label   => "test release archive",
            Dir     => Root,
            Program => Archiver,
            Args    => Project_Tools.Processes.Arguments
              ([Project_Tools.Processes.Argument ("t"),
                Project_Tools.Processes.Argument (Archive)]),
            Output  => Output,
            Quiet   => True);

      if Status /= 0 then
         Project_Tools.Release_Checks.Fail
           ("release archive integrity test failed with status" & Integer'Image (Status));
      end if;

      Ada.Text_IO.Put_Line (Archive);
   end Generate_Release_Archive;

   function Built_Command_Path (Executable : String) return String;

   function Built_Root_Path return String;

   procedure Generate_Release_Checksums is
      use Ada.Strings.Unbounded;
      Content : Unbounded_String;
      Base    : constant String := Root;

      procedure Add_File
        (Label         : String;
         Display_Path  : String;
         Artifact_Path : String)
      is
      begin
         Append
           (Content,
            Label & " " & Display_Path
            & " fnv1a64=" & Project_Tools.Release_Checks.FNV1A64 (Artifact_Path)
            & Character'Val (10));
      end Add_File;

      procedure Add_File (Label : String; Path : String) is
      begin
         Add_File (Label, Path, Project_Tools.Files.Join (Base, Path));
      end Add_File;
   begin
      Append
        (Content,
         "posix-tools release checksums " & Posix_Tools.Version.Version_String
         & Character'Val (10));
      Add_File ("manifest", "generated/package-manifest.txt");
      Add_File ("archive", Release_Archive_Path);

      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Executable   : constant String := Posix_Tools.Command_Inventory.Executable (I);
            Display_Path : constant String := "tools/" & Executable & "/bin/" & Executable;
         begin
            Add_File ("executable", Display_Path, Built_Command_Path (Executable));
         end;
      end loop;

      Add_File ("executable", "bin/posix-tools", Built_Root_Path);

      Project_Tools.Files.Write_Raw_File
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
             (Project_Tools.Files.Join (Root, "tests/src/command_tests-suite_entries.adb"), Needle);
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
         elsif To_String (Row.Posix_Reference) = "Project extension"
           and then not
             (Project_Tools.Text.Contains (Id_Text, "-EXT-")
              or else Posix_Tools.Text.Matching.Starts_With (Id_Text, "NONPOSIX-"))
         then
            Project_Tools.Release_Checks.Fail
              (Id_Text & " records a project extension without an extension identifier");
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
                     Line : constant String :=
                       Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                         (Requirements (Start .. I - 1));
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
                     Line : constant String :=
                       Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                         (Regressions (Start .. I - 1));
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
            Project_Tools.Release_Checks.Fail ("command inventory is empty");
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
               Line : constant String :=
                 Posix_Tools.Text.Line_Breaks.Without_Trailing_CR
                   (Inventory_Csv (Start .. Inventory_Csv'Last));
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

         if Posix_Tools.Command_Inventory.Posix_Status (I) = "known_deviation" then
            if not Has_Known_Deviation_Metadata (Posix_Tools.Command_Inventory.Executable (I)) then
               Project_Tools.Release_Checks.Fail
                 ("inventory command is marked known_deviation without matching requirement row: "
                  & Posix_Tools.Command_Inventory.Executable (I));
            end if;
         elsif Has_Known_Deviation_Metadata (Posix_Tools.Command_Inventory.Executable (I)) then
            Project_Tools.Release_Checks.Fail
              ("requirement registry has a known deviation for inventory command not marked known_deviation: "
               & Posix_Tools.Command_Inventory.Executable (I));
         end if;
      end loop;
      Project_Tools.Release_Checks.Require_Text
        (Check, "generated/requirements.csv", "Conforming with extensions");
      Project_Tools.Release_Checks.Require_Text
        (Check, "docs/conformance.md", "POSIX.1-2024");
      Ada.Text_IO.Put_Line ("conformance metadata checks passed");
   end Run_Conformance_Checks;

   procedure Run_Format_Checks is
   begin
      Format_Checks.Run (Root);
   end Run_Format_Checks;

   procedure Run_Build is
   begin
      Build_Checks.Run (Root);
   end Run_Build;

   function Prove_Args
     (Unit_Name : String;
      Mode      : String;
      Level     : String := "1")
      return Project_Tools.Processes.Argument_Vectors.Vector is
   begin
      return Project_Tools.Processes.Arguments
        ([Project_Tools.Processes.Argument ("-P"),
          Project_Tools.Processes.Argument ("posix_tools_proof.gpr"),
          Project_Tools.Processes.Argument ("-u"),
          Project_Tools.Processes.Argument (Unit_Name),
          Project_Tools.Processes.Argument ("--mode=" & Mode),
          Project_Tools.Processes.Argument ("--level=" & Level),
          Project_Tools.Processes.Argument ("--checks-as-errors=on"),
          Project_Tools.Processes.Argument ("--warnings=error"),
          Project_Tools.Processes.Argument ("--prover=z3")]);
   end Prove_Args;

   procedure Prove_Target
     (Gnatprove : String;
      Label     : String;
      Unit_Name : String;
      Mode      : String;
      Level     : String := "1")
   is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          (Label   => Label,
           Dir     => Project_Tools.Files.Join (Root, "common"),
           Program => Gnatprove,
           Args    => Prove_Args (Unit_Name, Mode, Level));
   begin
      if Status /= 0 then
         Project_Tools.Release_Checks.Fail
           ("proof target " & Unit_Name & " failed in " & Mode & " mode");
      end if;
   end Prove_Target;

   procedure Run_Proof_Checks is
      procedure Run_Targets is new Proof_Targets (Prove_Target);
      Gnatprove : constant String := Project_Tools.Processes.Locate_Command ("gnatprove");
   begin
      if Gnatprove = "" then
         Project_Tools.Release_Checks.Fail
           ("gnatprove command not found for proof checks; install it with `alr -n install gnatprove`");
      end if;

      Run_Targets (Gnatprove);
      Ada.Text_IO.Put_Line ("proof checks passed");
   end Run_Proof_Checks;

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
         return Ada.Directories.Full_Name (Base_Path);
      elsif Project_Tools.Files.File_Exists (Base_Path & ".exe") then
         return Ada.Directories.Full_Name (Base_Path & ".exe");
      else
         return Base_Path;
      end if;
   end Built_Command_Path;

   function Built_Root_Path return String is
      Base_Path : constant String := Project_Tools.Files.Join (Root, "bin/posix-tools");
   begin
      if Project_Tools.Files.File_Exists (Base_Path) then
         return Ada.Directories.Full_Name (Base_Path);
      elsif Project_Tools.Files.File_Exists (Base_Path & ".exe") then
         return Ada.Directories.Full_Name (Base_Path & ".exe");
      else
         return Base_Path;
      end if;
   end Built_Root_Path;

   function Built_Test_Runner_Path return String is
      Base_Path : constant String := Project_Tools.Files.Join (Root, "tests/bin/posix_tools_tests");
   begin
      if Project_Tools.Files.File_Exists (Base_Path) then
         return Ada.Directories.Full_Name (Base_Path);
      elsif Project_Tools.Files.File_Exists (Base_Path & ".exe") then
         return Ada.Directories.Full_Name (Base_Path & ".exe");
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

      procedure Expect_Usage_Error
        (Label : String;
         Args  : Project_Tools.Processes.Argument_Vectors.Vector)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture_Command
             (Command    => Runner_Path,
              Arguments  => Args,
              Err_To_Out => True);
      begin
         if Captured.Status /= 2 then
            Project_Tools.Release_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status)
               & " instead of usage status 2");
         end if;
      end Expect_Usage_Error;
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
        ("test selector suite cp",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("cp")]),
         "command:cp");
      Expect_Selector
        ("test selector suite xargs",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("xargs")]),
         "command:xargs");
      Expect_Selector
        ("test selector suite root",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("root")]),
         "command:root");
      Expect_Selector
        ("test selector suite command",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("command")]),
         "command:basename");
      Expect_Selector
        ("test selector category unit",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("unit")]),
         "basic:numbers");
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
      Expect_Selector
        ("test selector command regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-STDOUT-0004");
      Expect_Selector
        ("test selector env regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-ENV-0001");
      Expect_Selector
        ("test selector verbose regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-VERBOSE-0001");
      Expect_Selector
        ("test selector xargs regression",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("regression")]),
         "regression:REG-XARGS-0001");
      Expect_Selector
        ("test selector category locale",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("locale")]),
         "locale:help");
      Expect_Selector
        ("test selector category presentation",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("presentation")]),
         "presentation:styling");
      Expect_Usage_Error
        ("test selector missing suite value",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite")]));
      Expect_Usage_Error
        ("test selector unknown suite",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--suite"),
             Project_Tools.Processes.Argument ("unknown")]));
      Expect_Usage_Error
        ("test selector unknown category",
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("test"),
             Project_Tools.Processes.Argument ("--category"),
             Project_Tools.Processes.Argument ("unknown")]));

      Ada.Text_IO.Put_Line ("test selector smoke checks passed");
   end Run_Test_Selector_Smoke;

   procedure Run_Staged_Verification is
   begin
      declare
         Status : constant String :=
           Posix_Tools.Host_Adapters.Executables.Verify_Identity_At_Path
             ("posix-tools", Built_Root_Path);
      begin
         if Status /= "ok" then
            Project_Tools.Release_Checks.Fail
              ("staged verification failed for posix-tools: " & Status);
         end if;
      end;

      declare
         Status : constant String :=
           Posix_Tools.Host_Adapters.Executables.Verify_Identity_At_Path
             ("posix-tools", Built_Root_Path, "0.0.0");
      begin
         if Status /= "wrong version" then
            Project_Tools.Release_Checks.Fail
              ("staged verification wrong-version classification failed for posix-tools: " & Status);
         end if;
      end;

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

   procedure Run_Executable_Integration_Smoke is
      use Ada.Strings.Unbounded;

      function Display_Output (Text : String) return String is
         Result : Unbounded_String;
      begin
         for Ch of Text loop
            case Ch is
               when Character'Val (10) =>
                  Append (Result, "\n");
               when Character'Val (13) =>
                  Append (Result, "\r");
               when Character'Val (9) =>
                  Append (Result, "\t");
               when others =>
                  Append (Result, Ch);
            end case;
         end loop;

         return To_String (Result);
      end Display_Output;

      procedure Expect_Output
        (Label           : String;
         Program         : String;
         Args            : Project_Tools.Processes.Argument_Vectors.Vector;
         Expected_Status : Integer;
         Expected_Output : String)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture
             (Label   => Label,
              Dir     => Root,
              Program => Program,
              Args    => Args,
              Quiet   => True);
      begin
         if Captured.Status /= Expected_Status then
            Project_Tools.Release_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status)
               & " instead of" & Integer'Image (Expected_Status));
         elsif To_String (Captured.Output) /= Expected_Output then
            Project_Tools.Release_Checks.Fail
              (Label & " produced unexpected output: expected """
               & Display_Output (Expected_Output) & """ actual """
               & Display_Output (To_String (Captured.Output)) & """");
         end if;
      end Expect_Output;

      procedure Expect_Nonempty_Line
        (Label   : String;
         Program : String;
         Args    : Project_Tools.Processes.Argument_Vectors.Vector)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture
             (Label   => Label,
              Dir     => Root,
              Program => Program,
              Args    => Args,
              Quiet   => True);
         Output : constant String := To_String (Captured.Output);
      begin
         if Captured.Status /= 0 then
            Project_Tools.Release_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status));
         elsif Output'Length <= 1 or else Output (Output'Last) /= Character'Val (10) then
            Project_Tools.Release_Checks.Fail (Label & " did not produce one nonempty line");
         end if;
      end Expect_Nonempty_Line;

      procedure Expect_Output_With_Input
        (Label           : String;
         Program         : String;
         Args            : Project_Tools.Processes.Argument_Vectors.Vector;
         Input           : String;
         Expected_Status : Integer;
         Expected_Output : String)
      is
         Captured : constant Project_Tools.Processes.Captured_Process :=
           Project_Tools.Processes.Capture_Command
             (Command   => Program,
              Arguments => Args,
              Input     => Input);
      begin
         if Captured.Status /= Expected_Status then
            Project_Tools.Release_Checks.Fail
              (Label & " returned status" & Integer'Image (Captured.Status)
               & " instead of" & Integer'Image (Expected_Status));
         elsif To_String (Captured.Output) /= Expected_Output then
            Project_Tools.Release_Checks.Fail
              (Label & " produced unexpected output: expected """
               & Display_Output (Expected_Output) & """ actual """
               & Display_Output (To_String (Captured.Output)) & """");
         end if;
      end Expect_Output_With_Input;

      LF : constant Character := Character'Val (10);

      function Identity_Output (Command : String) return String is
      begin
         return
           "schema=1" & LF
           & "project=posix-tools" & LF
           & "command=" & Command & LF
           & "version=" & Posix_Tools.Version.Version_String & LF;
      end Identity_Output;

      Smoke_File : constant String :=
        Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-smoke.txt");
      Smoke_Leaf : constant String := "posix-tools-executable-smoke.txt";

      procedure Expect_File (Label, Path, Expected_Content : String) is
      begin
         if not Project_Tools.Files.File_Exists (Path) then
            Project_Tools.Release_Checks.Fail (Label & " did not create expected file");
         else
            declare
               Actual_Content : constant String := Project_Tools.Files.Read_Raw_File (Path);
            begin
               if Actual_Content /= Expected_Content then
                  Project_Tools.Release_Checks.Fail
                    (Label & " created file with unexpected content: expected """
                     & Display_Output (Expected_Content) & """ actual """
                     & Display_Output (Actual_Content) & """");
               end if;
            end;
         end if;
      end Expect_File;

      procedure Remove_Path (Path : String) is
      begin
         if Project_Tools.Files.Directory_Exists (Path) then
            Project_Tools.Files.Delete_Tree (Path);
         else
            Project_Tools.Files.Delete_File_If_Present (Path);
         end if;
      end Remove_Path;
   begin
      Expect_Output
        ("root executable version",
         Built_Root_Path,
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--version")]),
         0,
         "posix-tools " & Posix_Tools.Version.Version_String & LF);

      Expect_Output
        ("root executable identity",
         Built_Root_Path,
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--posix-tools-identify")]),
         0,
         Identity_Output ("posix-tools"));

      Expect_Nonempty_Line
        ("root executable help",
         Built_Root_Path,
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--help")]));

      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Executable : constant String := Posix_Tools.Command_Inventory.Executable (I);
         begin
            Expect_Output
              (Executable & " executable version",
               Built_Command_Path (Executable),
               Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--version")]),
               0,
               Executable & " (posix-tools) " & Posix_Tools.Version.Version_String & LF);

            Expect_Output
              (Executable & " executable identity",
               Built_Command_Path (Executable),
               Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--posix-tools-identify")]),
               0,
               Identity_Output (Executable));

            Expect_Nonempty_Line
              (Executable & " executable help",
               Built_Command_Path (Executable),
               Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("--help")]));
         end;
      end loop;

      Project_Tools.Files.Write_Raw_File (Smoke_File, "alpha" & LF & "beta" & LF);

      Expect_Output
        ("basename executable data",
         Built_Command_Path ("basename"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         Smoke_Leaf & LF);

      Expect_Output
        ("cat executable data",
         Built_Command_Path ("cat"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF & "beta" & LF);

      Expect_Output
        ("dirname executable data",
         Built_Command_Path ("dirname"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         Posix_Tools.Paths.Dirname (Smoke_File) & LF);

      Expect_Output
        ("echo executable data",
         Built_Command_Path ("echo"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("alpha"),
             Project_Tools.Processes.Argument ("beta")]),
         0,
         "alpha beta" & LF);

      Expect_Output
        ("printf executable data",
         Built_Command_Path ("printf"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("%s:%s\n"),
             Project_Tools.Processes.Argument ("alpha"),
             Project_Tools.Processes.Argument ("beta")]),
         0,
         "alpha:beta" & LF);

      Expect_Output
        ("date executable data",
         Built_Command_Path ("date"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-u"),
                                             Project_Tools.Processes.Argument ("+%Z")]),
         0,
         "UTC" & LF);

      Expect_Output
        ("dd executable data",
         Built_Command_Path ("dd"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("if=" & Smoke_File),
                                             Project_Tools.Processes.Argument ("bs=5"),
                                             Project_Tools.Processes.Argument ("count=1")]),
         0,
         "alpha");

      Expect_Output
        ("env executable data",
         Built_Command_Path ("env"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-i"),
                                             Project_Tools.Processes.Argument ("NAME=value")]),
         0,
         "NAME=value" & LF);

      Expect_Output
        ("false executable status",
         Built_Command_Path ("false"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("ignored")]),
         1,
         "");

      Expect_Output
        ("head executable data",
         Built_Command_Path ("head"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("-n"),
             Project_Tools.Processes.Argument ("1"),
             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF);

      declare
         Copy_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-copy.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Copy_Target);
         Expect_Output
           ("cp executable data",
            Built_Command_Path ("cp"),
            Project_Tools.Processes.Arguments
              ([Project_Tools.Processes.Argument (Smoke_File),
                Project_Tools.Processes.Argument (Copy_Target)]),
            0,
            "");
         Expect_Output
           ("cp executable copied data",
            Built_Command_Path ("cat"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Copy_Target)]),
            0,
            "alpha" & LF & "beta" & LF);
         Project_Tools.Files.Delete_File_If_Present (Copy_Target);
      end;

      Expect_Output
        ("find executable data",
         Built_Command_Path ("find"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File),
                                             Project_Tools.Processes.Argument ("-type"),
                                             Project_Tools.Processes.Argument ("f")]),
         0,
         Smoke_File & LF);

      declare
         Link_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-link.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Link_Target);
         Expect_Output
           ("ln executable data",
            Built_Command_Path ("ln"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File),
                                                Project_Tools.Processes.Argument (Link_Target)]),
            0,
            "");
         Expect_Output
           ("ln executable linked data",
            Built_Command_Path ("cat"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Link_Target)]),
            0,
            "alpha" & LF & "beta" & LF);
         Project_Tools.Files.Delete_File_If_Present (Link_Target);
      end;

      declare
         Made_Dir : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-mkdir");
      begin
         Remove_Path (Made_Dir);
         Expect_Output
           ("mkdir executable data",
            Built_Command_Path ("mkdir"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Made_Dir)]),
            0,
            "");
         if not Project_Tools.Files.Directory_Exists (Made_Dir) then
            Project_Tools.Release_Checks.Fail ("mkdir executable data did not create directory");
         end if;
         Expect_Output
           ("rmdir executable data",
            Built_Command_Path ("rmdir"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Made_Dir)]),
            0,
            "");
         if Project_Tools.Files.Directory_Exists (Made_Dir) then
            Project_Tools.Release_Checks.Fail ("rmdir executable data did not remove directory");
         end if;
      end;

      declare
         Mv_Source : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-mv-source.txt");
         Mv_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-mv-target.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Mv_Source);
         Project_Tools.Files.Delete_File_If_Present (Mv_Target);
         Project_Tools.Files.Write_Raw_File (Mv_Source, "move-data");
         Expect_Output
           ("mv executable data",
            Built_Command_Path ("mv"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Mv_Source),
                                                Project_Tools.Processes.Argument (Mv_Target)]),
            0,
            "");
         Expect_File ("mv executable data", Mv_Target, "move-data");
         Project_Tools.Files.Delete_File_If_Present (Mv_Target);
      end;

      declare
         Rm_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-rm.txt");
      begin
         Project_Tools.Files.Write_Raw_File (Rm_Target, "remove-data");
         Expect_Output
           ("rm executable data",
            Built_Command_Path ("rm"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Rm_Target)]),
            0,
            "");
         if Project_Tools.Files.File_Exists (Rm_Target) then
            Project_Tools.Release_Checks.Fail ("rm executable data did not remove file");
         end if;
      end;

      Expect_Nonempty_Line
        ("pwd executable data",
         Built_Command_Path ("pwd"),
         Project_Tools.Processes.No_Arguments);

      Project_Tools.Files.Write_Raw_File (Smoke_File, "beta" & LF & "alpha");
      Expect_Output
        ("sort executable data",
         Built_Command_Path ("sort"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "alpha" & LF & "beta" & LF);
      Project_Tools.Files.Write_Raw_File (Smoke_File, "alpha" & LF & "beta" & LF);

      Expect_Output
        ("tail executable data",
         Built_Command_Path ("tail"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("-n"),
             Project_Tools.Processes.Argument ("1"),
             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "beta" & LF);

      Expect_Output
        ("true executable status",
         Built_Command_Path ("true"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("ignored")]),
         0,
         "");

      declare
         Tee_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-tee.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Tee_Target);
         Expect_Output_With_Input
           ("tee executable data",
            Built_Command_Path ("tee"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Tee_Target)]),
            "tee-data",
            0,
            "tee-data");
         Expect_File ("tee executable data", Tee_Target, "tee-data" & LF);
         Project_Tools.Files.Delete_File_If_Present (Tee_Target);
      end;

      Expect_Output
        ("test executable status",
         Built_Command_Path ("test"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-f"),
                                             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "");

      declare
         Touch_Target : constant String :=
           Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-executable-touch.txt");
      begin
         Project_Tools.Files.Delete_File_If_Present (Touch_Target);
         Expect_Output
           ("touch executable data",
            Built_Command_Path ("touch"),
            Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument (Touch_Target)]),
            0,
            "");
         Expect_File ("touch executable data", Touch_Target, "");
         Project_Tools.Files.Delete_File_If_Present (Touch_Target);
      end;

      Expect_Output_With_Input
        ("tr executable data",
         Built_Command_Path ("tr"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("a-z"),
             Project_Tools.Processes.Argument ("A-Z")]),
         "alpha",
         0,
         "ALPHA");

      Expect_Output_With_Input
        ("uniq executable data",
         Built_Command_Path ("uniq"),
         Project_Tools.Processes.No_Arguments,
         "alpha" & LF & "alpha" & LF & "beta",
         0,
         "alpha" & LF & "beta");

      Expect_Output_With_Input
        ("xargs executable data",
         Built_Command_Path ("xargs"),
         Project_Tools.Processes.Arguments ([Project_Tools.Processes.Argument ("-r")]),
         "",
         0,
         "");

      Expect_Output
        ("wc executable data",
         Built_Command_Path ("wc"),
         Project_Tools.Processes.Arguments
           ([Project_Tools.Processes.Argument ("-c"),
             Project_Tools.Processes.Argument (Smoke_File)]),
         0,
         "11 " & Smoke_File & LF);

      Project_Tools.Files.Delete_File_If_Present (Smoke_File);

      Ada.Text_IO.Put_Line ("executable integration smoke checks passed");
   end Run_Executable_Integration_Smoke;

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
      elsif Posix_Tools.Command_Inventory.Contains_Executable (Name) then
         return "command:" & Name;
      else
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "posix_tools_tests: suite '" & Name & "' has no registered AUnit tests yet");
         raise Invalid_Usage;
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
      Run_Executable_Integration_Smoke;
      Generate_Release_Archive;
      Generate_Release_Checksums;
      Run_Metadata_Checks;
      Run_Format_Checks;
      Run_Conformance_Checks;
      Run_Proof_Checks;
      Run_Tests;
   elsif Command = "release" then
      Require_Clean_Source_Tree;
      Generate_Docs;
      Generate_Package_Manifest;
      Run_Build;
      Run_Test_Selector_Smoke;
      Run_Staged_Verification;
      Run_Executable_Integration_Smoke;
      Generate_Release_Archive;
      Generate_Release_Checksums;
      Run_Metadata_Checks;
      Run_Format_Checks;
      Run_Conformance_Checks;
      Run_Proof_Checks;
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
   elsif Command = "prove" then
      Run_Metadata_Checks;
      Run_Proof_Checks;
      Ada.Text_IO.Put_Line ("prove: completed by Ada project_tools driver");
   elsif Command = "package" then
      Generate_Package_Manifest;
      Generate_Release_Archive;
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
   when Occurrence : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "posix_tools_tests: internal tooling failure");
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         Ada.Exceptions.Exception_Information (Occurrence));
      Ada.Command_Line.Set_Exit_Status (125);
end Posix_Tools_Tests;
