with Ada.Command_Line;
with Ada.Containers.Indefinite_Vectors;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Ada.Text_IO.Text_Streams;
with Greplib;
with Greplib.Byte_Strings;
with Greplib.Collected;
with Greplib.Diagnostics;
with Greplib.Events;
with Greplib.Options;
with Greplib.Patterns;
with Greplib.Results;
with Greplib.Paths;
with Posix_Tools.Host_Adapters.Streams;
with Posix_Tools.Process_Entry;
with Posix_Tools.Version;

procedure Grep is
   use Ada.Strings.Unbounded;
   use type Greplib.Wide_Count;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Positive, Unbounded_String);

   type Invocation is record
      Patterns : Greplib.Patterns.Pattern_List;
      Pattern_Count : Natural := 0;
      Files : String_Vectors.Vector;
      Fixed_Strings : Boolean := False;
      Count_Only : Boolean := False;
      List_With_Matches : Boolean := False;
      List_Without_Matches : Boolean := False;
      Quiet : Boolean := False;
      Invert_Match : Boolean := False;
      Ignore_Case : Boolean := False;
      Whole_Record : Boolean := False;
      Line_Number : Boolean := False;
      Force_With_Filename : Boolean := False;
      Force_Without_Filename : Boolean := False;
      Suppress_Diagnostics : Boolean := False;
      Have_Explicit_Pattern : Boolean := False;
      Valid : Boolean := True;
   end record;

   function Write_Out (Text : String) return Boolean
     renames Posix_Tools.Host_Adapters.Streams.Write_Standard_Output;

   function Write_Err (Text : String) return Boolean
     renames Posix_Tools.Host_Adapters.Streams.Write_Standard_Error;

   procedure Put_Error (Text : String) is
      Ignored : constant Boolean := Write_Err ("grep: " & Text & ASCII.LF);
   begin
      null;
   end Put_Error;

   procedure Add_Pattern (Config : in out Invocation; Text : String) is
   begin
      if Config.Fixed_Strings then
         Greplib.Patterns.Append
           (Config.Patterns, Greplib.Patterns.Fixed_String_Pattern (Text));
      else
         Greplib.Patterns.Append
           (Config.Patterns, Greplib.Patterns.Regular_Expression_Pattern (Text));
      end if;
      Config.Pattern_Count := Config.Pattern_Count + 1;
   end Add_Pattern;

   procedure Add_File_Patterns
     (Config : in out Invocation;
      Path : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Add_Pattern (Config, Ada.Text_IO.Get_Line (File));
      end loop;
      Ada.Text_IO.Close (File);
   exception
      when Error : others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Put_Error
           (Path & ": cannot read pattern file: "
            & Ada.Exceptions.Exception_Message (Error));
         Config.Valid := False;
   end Add_File_Patterns;

   function Needs_File_Prefix (Config : Invocation) return Boolean is
   begin
      if Config.Force_Without_Filename then
         return False;
      elsif Config.Force_With_Filename then
         return True;
      else
         return Natural (Config.Files.Length) > 1;
      end if;
   end Needs_File_Prefix;

   procedure Usage is
      Ignored : constant Boolean :=
        Write_Err
          ("usage: grep [-FcilLqvinHhxs] [-e pattern] [-f pattern_file] pattern [file...]" & ASCII.LF);
   begin
      null;
   end Usage;

   procedure Version is
      Ignored : constant Boolean :=
        Write_Out
          ("grep " & Posix_Tools.Version.Version_String & ASCII.LF
           & "engine greplib" & ASCII.LF
           & "license MIT" & ASCII.LF);
   begin
      null;
   end Version;

   procedure Help is
      Ignored : constant Boolean :=
        Write_Out
          ("Usage: grep [OPTION]... PATTERN [FILE]..." & ASCII.LF
           & "Search FILEs or standard input for records matching PATTERN." & ASCII.LF
           & ASCII.LF
           & "  -e PATTERN   use PATTERN as a search pattern" & ASCII.LF
           & "  -f FILE      read patterns from FILE" & ASCII.LF
           & "  -F           treat patterns as fixed strings" & ASCII.LF
           & "  -i           ignore ASCII case differences" & ASCII.LF
           & "  -v           select non-matching records" & ASCII.LF
           & "  -c           print selected-record counts" & ASCII.LF
           & "  -l, -L       print file names with or without selected records" & ASCII.LF
           & "  -q           suppress output and stop after the first match" & ASCII.LF
           & "  -n           prefix selected records with line numbers" & ASCII.LF
           & "  -H, -h       force or suppress file-name prefixes" & ASCII.LF
           & "  -x           require a whole-record match" & ASCII.LF
           & "  -s           suppress input diagnostics" & ASCII.LF
           & "      --help, --version, --posix-tools-identify" & ASCII.LF);
   begin
      null;
   end Help;

   procedure Parse_Short
     (Config : in out Invocation;
      Arg : String;
      Index : in out Positive) is
      J : Positive := 2;
   begin
      while J <= Arg'Last loop
         case Arg (J) is
            when 'F' =>
               Config.Fixed_Strings := True;
            when 'c' =>
               Config.Count_Only := True;
            when 'i' =>
               Config.Ignore_Case := True;
            when 'l' =>
               Config.List_With_Matches := True;
            when 'L' =>
               Config.List_Without_Matches := True;
            when 'q' =>
               Config.Quiet := True;
            when 'v' =>
               Config.Invert_Match := True;
            when 'x' =>
               Config.Whole_Record := True;
            when 'n' =>
               Config.Line_Number := True;
            when 'H' =>
               Config.Force_With_Filename := True;
            when 'h' =>
               Config.Force_Without_Filename := True;
            when 's' =>
               Config.Suppress_Diagnostics := True;
            when 'E' =>
               null;
            when 'e' | 'f' =>
               declare
                  Option : constant Character := Arg (J);
                  Value : Unbounded_String;
               begin
                  if J < Arg'Last then
                     Value := To_Unbounded_String (Arg (J + 1 .. Arg'Last));
                     J := Arg'Last;
                  elsif Index < Ada.Command_Line.Argument_Count then
                     Index := Index + 1;
                     Value := To_Unbounded_String (Ada.Command_Line.Argument (Index));
                  else
                     Put_Error ("option -" & Option & " requires an argument");
                     Config.Valid := False;
                     return;
                  end if;

                  if Option = 'e' then
                     Add_Pattern (Config, To_String (Value));
                     Config.Have_Explicit_Pattern := True;
                  else
                     Add_File_Patterns (Config, To_String (Value));
                     Config.Have_Explicit_Pattern := True;
                  end if;
               end;
            when others =>
               Put_Error ("unknown option -" & Arg (J));
               Config.Valid := False;
               return;
         end case;
         J := J + 1;
      end loop;
   end Parse_Short;

   procedure Parse (Config : in out Invocation) is
      End_Options : Boolean := False;
      Pattern_From_Operand : Boolean := False;
      I : Positive := 1;
   begin
      while I <= Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (I);
         begin
            if not End_Options and then Arg = "--" then
               End_Options := True;
            elsif not End_Options and then Arg = "--help" then
               Help;
               Posix_Tools.Process_Entry.Set_Exit_Status (0);
               raise Program_Error with "handled";
            elsif not End_Options and then Arg = "--version" then
               Version;
               Posix_Tools.Process_Entry.Set_Exit_Status (0);
               raise Program_Error with "handled";
            elsif not End_Options and then Arg'Length > 1 and then Arg (Arg'First) = '-' then
               Parse_Short (Config, Arg, I);
               if not Config.Valid then
                  return;
               end if;
            elsif Config.Have_Explicit_Pattern or else Pattern_From_Operand then
               Config.Files.Append (To_Unbounded_String (Arg));
            else
               Add_Pattern (Config, Arg);
               Pattern_From_Operand := True;
            end if;
         end;
         I := I + 1;
      end loop;

      if Config.Pattern_Count = 0 then
         Put_Error ("missing pattern");
         Config.Valid := False;
      end if;
   end Parse;

   procedure Report_Diagnostics
     (List : Greplib.Diagnostics.Diagnostic_List;
      Suppress : Boolean) is
   begin
      if Suppress then
         return;
      end if;

      for I in 1 .. Natural (Greplib.Diagnostics.Length (List)) loop
         declare
            Diagnostic : constant Greplib.Diagnostics.Diagnostic :=
              Greplib.Diagnostics.Element (List, I);
            Text : constant String := Greplib.Diagnostics.Debug_Image (Diagnostic);
            Ignored : constant Boolean := Write_Err ("grep: " & Text & ASCII.LF);
         begin
            null;
         end;
      end loop;
   end Report_Diagnostics;

   function Count_Image (Value : Greplib.Wide_Count) return String is
      Image : constant String := Greplib.Wide_Count'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Count_Image;

   function Source_Name
     (Configured_Name : String;
      Event : Greplib.Events.Search_Event) return String is
   begin
      if Configured_Name /= "" then
         return Configured_Name;
      else
         return Greplib.Paths.Image (Greplib.Events.Source_Path (Event));
      end if;
   end Source_Name;

   procedure Render_Events
     (Config : Invocation;
      File_Name : String;
      Result : Greplib.Collected.Collected_Result) is
      Prefix_File : constant Boolean := Needs_File_Prefix (Config);
   begin
      for I in 1 .. Natural (Result.Events.Length) loop
         declare
            Event : constant Greplib.Events.Search_Event := Result.Events.Element (I);
         begin
            case Greplib.Events.Kind (Event) is
               when Greplib.Events.Selected_Record =>
                  declare
                     Prefix : Unbounded_String;
                     Content : constant String :=
                       Greplib.Byte_Strings.To_String (Greplib.Events.Content (Event));
                  begin
                     if Prefix_File then
                        Append (Prefix, Source_Name (File_Name, Event) & ":");
                     end if;
                     if Config.Line_Number then
                        Append (Prefix, Count_Image (Greplib.Events.Record_No (Event)) & ":");
                     end if;
                     declare
                        Ignored : constant Boolean :=
                          Write_Out (To_String (Prefix) & Content & ASCII.LF);
                     begin
                        null;
                     end;
                  end;
               when Greplib.Events.Count_Result =>
                  declare
                     Prefix : constant String :=
                       (if Prefix_File then Source_Name (File_Name, Event) & ":" else "");
                     Ignored : constant Boolean :=
                       Write_Out (Prefix & Count_Image (Greplib.Events.Count (Event)) & ASCII.LF);
                  begin
                     null;
                  end;
               when Greplib.Events.Source_Name_Result =>
                  declare
                     Expected : constant Boolean := not Config.List_Without_Matches;
                  begin
                     if Greplib.Events.Had_Match (Event) = Expected then
                        declare
                           Ignored : constant Boolean :=
                             Write_Out (Source_Name (File_Name, Event) & ASCII.LF);
                        begin
                           null;
                        end;
                     end if;
                  end;
               when others =>
                  null;
            end case;
         end;
      end loop;
   end Render_Events;

   procedure Apply_Mode
     (Config : Invocation;
      Options : in out Greplib.Options.Search_Options) is
   begin
      Options.Invert_Match := Config.Invert_Match;
      if Config.Quiet then
         Options.Mode := Greplib.Options.Quiet;
      elsif Config.Count_Only then
         Options.Mode := Greplib.Options.Count_Selected_Records;
      elsif Config.List_With_Matches then
         Options.Mode := Greplib.Options.Source_Names_With_Matches;
      elsif Config.List_Without_Matches then
         Options.Mode := Greplib.Options.Source_Names_Without_Matches;
      else
         Options.Mode := Greplib.Options.Emit_Selected_Records;
      end if;
   end Apply_Mode;

   procedure Search_One
     (Config : Invocation;
      Set : Greplib.Patterns.Compiled_Pattern_Set;
      File_Name : String;
      Had_Selected : in out Boolean;
      Had_Error : in out Boolean) is
      Options : Greplib.Options.Search_Options;
      Collection : Greplib.Collected.Collection_Options;
      Result : Greplib.Collected.Collected_Result;
   begin
      Apply_Mode (Config, Options);
      Collection.On_Limit := Greplib.Collected.Continue_Without_Collecting;

      if File_Name = "-" then
         declare
            Stream : constant Ada.Text_IO.Text_Streams.Stream_Access :=
              Ada.Text_IO.Text_Streams.Stream (Ada.Text_IO.Standard_Input);
         begin
            Greplib.Collected.Search_Stream
              (Stream.all, Set, Options, Collection, Result);
         end;
      else
         Greplib.Collected.Search_File
           (Greplib.Paths.To_Path (File_Name), Set, Options, Collection, Result);
      end if;

      Render_Events (Config, File_Name, Result);
      Report_Diagnostics
        (Greplib.Results.Diagnostics (Result.Outcome), Config.Suppress_Diagnostics);

      declare
         Summary : constant Greplib.Results.Search_Summary :=
           Greplib.Results.Summary (Result.Outcome);
      begin
         Had_Selected :=
           Had_Selected or else Greplib.Results.Selected_Record_Count (Summary) > 0;
      end;

      case Greplib.Results.Status (Result.Outcome) is
         when Greplib.Results.Completed =>
            null;
         when Greplib.Results.Completed_With_Recoverable_Errors
            | Greplib.Results.Cancelled
            | Greplib.Results.Failed =>
            Had_Error := True;
      end case;
   end Search_One;

   Config : Invocation;
begin
   if Posix_Tools.Process_Entry.Is_Identity_Request then
      if not Posix_Tools.Process_Entry.Write_Identity ("grep") then
         Posix_Tools.Process_Entry.Set_Exit_Status (2);
      end if;
      return;
   end if;

   begin
      Parse (Config);
   exception
      when Program_Error =>
         return;
   end;

   if not Config.Valid then
      Usage;
      Posix_Tools.Process_Entry.Set_Exit_Status (2);
      return;
   end if;

   declare
      Compile_Options : Greplib.Patterns.Compilation_Options;
      Set : Greplib.Patterns.Compiled_Pattern_Set;
   begin
      Compile_Options.Case_Insensitive := Config.Ignore_Case;
      Compile_Options.Whole_Record := Config.Whole_Record;
      Set := Greplib.Patterns.Compile (Config.Patterns, Compile_Options);
      if not Greplib.Patterns.Is_Usable (Set) then
         Report_Diagnostics (Greplib.Patterns.Diagnostics (Set), Config.Suppress_Diagnostics);
         Posix_Tools.Process_Entry.Set_Exit_Status (2);
         return;
      end if;

      declare
         Had_Selected : Boolean := False;
         Had_Error : Boolean := False;
      begin
         if Config.Files.Is_Empty then
            Search_One (Config, Set, "-", Had_Selected, Had_Error);
         else
            for I in 1 .. Natural (Config.Files.Length) loop
               Search_One
                 (Config, Set, To_String (Config.Files.Element (I)), Had_Selected, Had_Error);
            end loop;
         end if;

         if Had_Error then
            Posix_Tools.Process_Entry.Set_Exit_Status (2);
         elsif Had_Selected then
            Posix_Tools.Process_Entry.Set_Exit_Status (0);
         else
            Posix_Tools.Process_Entry.Set_Exit_Status (1);
         end if;
      end;
   end;
exception
   when Error : others =>
      Put_Error ("internal error: " & Ada.Exceptions.Exception_Name (Error));
      Posix_Tools.Process_Entry.Set_Exit_Status (2);
end Grep;
