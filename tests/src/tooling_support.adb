with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Posix_Tools.Command_Inventory;
with Project_Tools.Files;

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
end Tooling_Support;
