with Ada.Directories;
with Hostkit;
with Hostkit.Process;
with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Version;
with Project_Tools.Files;
with Tooling_Checks;

package body Tooling_Support is
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

   function Built_Path (Base_Path : String) return String is
   begin
      if Project_Tools.Files.File_Exists (Base_Path) then
         return Ada.Directories.Full_Name (Base_Path);
      elsif Project_Tools.Files.File_Exists (Base_Path & ".exe") then
         return Ada.Directories.Full_Name (Base_Path & ".exe");
      else
         return Base_Path;
      end if;
   end Built_Path;

   function Built_Command_Path (Executable : String) return String is
     (Built_Path (Project_Tools.Files.Join (Root, "tools/" & Executable & "/bin/" & Executable)));

   function Built_Root_Path return String is
     (Built_Path (Project_Tools.Files.Join (Root, "bin/posix-tools")));

   function Built_Test_Runner_Path return String is
     (Built_Path (Project_Tools.Files.Join (Root, "tests/bin/posix_tools_tests")));

   function Release_Archive_Path return String is
     ("dist/posix-tools-" & Posix_Tools.Version.Version_String & "-source.7z");

   procedure Run_Within
     (Program    : String;
      Args       : Project_Tools.Processes.Argument_Vectors.Vector;
      Timeout    : Duration;
      Result     : out Project_Tools.Processes.Captured_Process;
      Started    : out Boolean;
      Timed_Out  : out Boolean;
      Input      : String := "";
      Err_To_Out : Boolean := False)
   is
      --  Scratch files under the ignored work directory; the driver runs
      --  one program at a time.
      Work        : constant String := Project_Tools.Files.Join (Root, "generated/test-work");
      Input_Path  : constant String := Project_Tools.Files.Join (Work, "tooling-run.in");
      Output_Path : constant String := Project_Tools.Files.Join (Work, "tooling-run.out");
      Error_Path  : constant String := Project_Tools.Files.Join (Work, "tooling-run.err");
      Arguments   : Hostkit.String_Vectors.Vector;
      Outcome     : Hostkit.Process.Process_Outcome;
   begin
      Ada.Directories.Create_Path (Work);
      --  An empty input rather than ours, so a program that reads its
      --  standard input sees its end at once.
      Project_Tools.Files.Write_Raw_File (Input_Path, Input);
      Project_Tools.Files.Delete_File_If_Present (Output_Path);
      Project_Tools.Files.Delete_File_If_Present (Error_Path);
      for Item of Args loop
         Arguments.Append (Item);
      end loop;

      Outcome :=
        Hostkit.Process.Run_Captured
          (Program           => Program,
           Arguments         => Arguments,
           Working_Directory => Root,
           Stdin_Path        => Input_Path,
           Stdout_Path       => Output_Path,
           Stderr_Path       => (if Err_To_Out then Output_Path else Error_Path),
           Timeout_Ms        => Natural (Timeout * 1000));

      Started := Outcome.Started;
      Timed_Out := Outcome.Timed_Out;
      Result :=
        (Status => (if Outcome.Started then Outcome.Exit_Status else 127),
         Output =>
           Ada.Strings.Unbounded.To_Unbounded_String
             (if Project_Tools.Files.File_Exists (Output_Path)
              then Project_Tools.Files.Read_Raw_File (Output_Path)
              else ""));
   end Run_Within;

   function Capture_Within
     (Label      : String;
      Program    : String;
      Args       : Project_Tools.Processes.Argument_Vectors.Vector;
      Input      : String := "";
      Err_To_Out : Boolean := False;
      Timeout    : Duration := 120.0) return Project_Tools.Processes.Captured_Process
   is
      Result    : Project_Tools.Processes.Captured_Process;
      Started   : Boolean;
      Timed_Out : Boolean;
   begin
      Run_Within (Program, Args, Timeout, Result, Started, Timed_Out, Input, Err_To_Out);
      if not Started then
         Tooling_Checks.Fail (Label & ": could not start " & Program);
      elsif Timed_Out then
         Tooling_Checks.Fail
           (Label & ": " & Program & " did not finish within"
            & Integer'Image (Integer (Timeout)) & " seconds");
      end if;

      return Result;
   end Capture_Within;

   function Display_Output (Text : String) return String is
      use Ada.Strings.Unbounded;
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

   function Boolean_Text (Value : Boolean) return String is
     (if Value then "true" else "false");

   function Command_Inventory_Csv return String is
      use Ada.Strings.Unbounded;
      package Inventory renames Posix_Tools.Command_Inventory;
      Content : Unbounded_String;
   begin
      Append
        (Content,
         "executable,crate,package,manifest_path,project_file_path,documentation_path,"
         & "release_included,posix_status,help,version,identity"
         & Character'Val (10));

      for I in 1 .. Inventory.Command_Count loop
         Append
           (Content,
            Inventory.Executable (I)
            & "," & Inventory.Crate (I)
            & "," & Inventory.Package_Name (I)
            & "," & Inventory.Manifest_Path (I)
            & "," & Inventory.Project_File_Path (I)
            & "," & Inventory.Documentation_Path (I)
            & "," & Boolean_Text (Inventory.Release_Included (I))
            & "," & Inventory.Posix_Status (I)
            & "," & Boolean_Text (Inventory.Has_Help (I))
            & "," & Boolean_Text (Inventory.Has_Version (I))
            & "," & Boolean_Text (Inventory.Has_Identity (I))
            & Character'Val (10));
      end loop;

      return To_String (Content);
   end Command_Inventory_Csv;

   function Manual_Index return String is
      use Ada.Strings.Unbounded;
      package Inventory renames Posix_Tools.Command_Inventory;
      Content : Unbounded_String;
   begin
      Append (Content, "# Generated Manual Index" & Character'Val (10) & Character'Val (10));
      Append
        (Content,
         "Version: " & Posix_Tools.Version.Version_String
         & Character'Val (10) & Character'Val (10));

      for I in 1 .. Inventory.Command_Count loop
         Append
           (Content,
            "- `" & Inventory.Executable (I) & "`: "
            & Inventory.Documentation_Path (I)
            & Character'Val (10));
      end loop;

      Append (Content, Character'Val (10));
      return To_String (Content);
   end Manual_Index;

   function Command_Reference_Index return String is
      use Ada.Strings.Unbounded;
      package Inventory renames Posix_Tools.Command_Inventory;
      Root_Entry    : constant String := "- [posix-tools](posix-tools.md)" & Character'Val (10);
      Content       : Unbounded_String;
      Root_Inserted : Boolean := False;
   begin
      Append (Content, "# Command References" & Character'Val (10) & Character'Val (10));
      Append (Content, "V1 command references:" & Character'Val (10) & Character'Val (10));

      for I in 1 .. Inventory.Command_Count loop
         if not Root_Inserted and then "posix-tools" < Inventory.Executable (I) then
            Append (Content, Root_Entry);
            Root_Inserted := True;
         end if;

         Append
           (Content,
            "- [" & Inventory.Executable (I) & "](" & Inventory.Executable (I) & ".md)"
            & Character'Val (10));
      end loop;

      if not Root_Inserted then
         Append (Content, Root_Entry);
      end if;

      return To_String (Content);
   end Command_Reference_Index;

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

   --  The manual page of Name from the reference document at Document_Path:
   --  the document's sections in the order man pages give them, and the
   --  document itself to see also. The root page has always ended with a
   --  blank line, which Trailing_Blank keeps.
   function Render_Manpage
     (Name           : String;
      Document_Path  : String;
      Trailing_Blank : Boolean) return String
   is
      use Ada.Strings.Unbounded;
      Document : constant String :=
        Project_Tools.Files.Read_Raw_File (Project_Tools.Files.Join (Root, Document_Path));
      Page     : Unbounded_String;

      procedure Append_Section (Heading : String; Source_Heading : String) is
         Text : constant String := Markdown_Section (Document, Source_Heading);
      begin
         if Text /= "" then
            Append (Page, ".SH " & Heading & Character'Val (10));
            Append (Page, Roff_Text (Text));
         end if;
      end Append_Section;
   begin
      Append (Page, ".TH " & Name & " 1" & Character'Val (10));
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
      Append (Page, Document_Path & Character'Val (10));
      if Trailing_Blank then
         Append (Page, Character'Val (10));
      end if;

      return To_String (Page);
   end Render_Manpage;

   function Command_Manpage (Index : Positive) return String is
     (Render_Manpage
        (Posix_Tools.Command_Inventory.Executable (Index),
         Posix_Tools.Command_Inventory.Documentation_Path (Index),
         Trailing_Blank => False));

   function Root_Manpage return String is
     (Render_Manpage ("posix-tools", "docs/commands/posix-tools.md", Trailing_Blank => True));
end Tooling_Support;
