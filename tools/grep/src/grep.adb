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
with Greplib.Directories;
with Greplib.Events;
with Greplib.Options;
with Greplib.Patterns;
with Greplib.Results;
with Greplib.Paths;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Host_Adapters.Environment;
with Posix_Tools.Host_Adapters.Host;
with Posix_Tools.Host_Adapters.Streams;
with Posix_Tools.Localization;
with Posix_Tools.Process_Entry;
with Posix_Tools.Text.Escaping;
with Posix_Tools.Version;

procedure Grep is
   use Ada.Strings.Unbounded;
   use type Greplib.Events.Event_Kind;
   use type Greplib.Wide_Count;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Positive, Unbounded_String);

   type Regex_Mode is (Basic_Regular_Expression, Extended_Regular_Expression);

   type Invocation is record
      Pattern_Texts : String_Vectors.Vector;
      Pattern_Count : Natural := 0;
      Files : String_Vectors.Vector;
      Fixed_Strings : Boolean := False;
      Regex : Regex_Mode := Basic_Regular_Expression;
      Count_Only : Boolean := False;
      List_With_Matches : Boolean := False;
      List_Without_Matches : Boolean := False;
      Quiet : Boolean := False;
      Recursive : Boolean := False;
      Invert_Match : Boolean := False;
      Ignore_Case : Boolean := False;
      Whole_Word : Boolean := False;
      Whole_Record : Boolean := False;
      Only_Matching : Boolean := False;
      Byte_Offset : Boolean := False;
      Maximum_Selected : Greplib.Wide_Count := 0;
      Before_Context : Greplib.Wide_Count := 0;
      After_Context : Greplib.Wide_Count := 0;
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

   function Locale return String is
      LC_All : constant String := Posix_Tools.Host_Adapters.Environment.Value ("LC_ALL");
      Lang   : constant String := Posix_Tools.Host_Adapters.Environment.Value ("LANG");
      Native : constant String := Posix_Tools.Host_Adapters.Host.Native_Locale;
   begin
      if LC_All /= "" then
         return LC_All;
      elsif Lang /= "" then
         return Lang;
      elsif Native /= "" then
         return Native;
      else
         return "en";
      end if;
   exception
      when Constraint_Error | Program_Error =>
         return "en";
   end Locale;

   function Escape_Untrusted (Text : String) return String is
   begin
      return Posix_Tools.Text.Escaping.Escape_Untrusted (Text);
   end Escape_Untrusted;

   function Localized
     (Key : String;
      Default : String) return String is
   begin
      return Posix_Tools.Localization.Text (Locale, Key, Default);
   end Localized;

   function Localized_1
     (Key : String;
      Name : String;
      Value : String;
      Default : String) return String is
   begin
      return Posix_Tools.Localization.Text_1
        (Locale, Key, Name, Escape_Untrusted (Value), Default);
   end Localized_1;

   procedure Put_Error (Text : String) is
      Ignored : constant Boolean := Write_Err ("grep: " & Text & ASCII.LF);
   begin
      null;
   end Put_Error;

   procedure Put_Localized_Error
     (Key : String;
      Default : String) is
   begin
      Put_Error (Localized (Key, Default));
   end Put_Localized_Error;

   procedure Put_Localized_Error_1
     (Key : String;
      Name : String;
      Value : String;
      Default : String) is
   begin
      Put_Error (Localized_1 (Key, Name, Value, Default));
   end Put_Localized_Error_1;

   function Count_Image (Value : Greplib.Wide_Count) return String is
      Image : constant String := Greplib.Wide_Count'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Count_Image;

   procedure Add_Pattern (Config : in out Invocation; Text : String) is
   begin
      Config.Pattern_Texts.Append (To_Unbounded_String (Text));
      Config.Pattern_Count := Config.Pattern_Count + 1;
   end Add_Pattern;

   function Basic_Interval_End (Pattern : String; First : Natural) return Natural is
      I : Natural := First;
   begin
      while I <= Pattern'Last loop
         if Pattern (I) = '\'
           and then I < Pattern'Last
           and then Pattern (I + 1) = '}'
         then
            return I;
         end if;
         I := I + 1;
      end loop;

      return 0;
   end Basic_Interval_End;

   function Bracket_Element_End
     (Pattern : String;
      First   : Natural;
      Marker  : Character) return Natural is
      I : Natural := First;
   begin
      while I < Pattern'Last loop
         if Pattern (I) = Marker and then Pattern (I + 1) = ']' then
            return I;
         end if;
         I := I + 1;
      end loop;

      return 0;
   end Bracket_Element_End;

   procedure Append_Class_Literal
     (Result : in out Unbounded_String;
      Text   : String) is
   begin
      for Ch of Text loop
         if Ch in '\' | ']' | '^' | '-' then
            Append (Result, '\');
         end if;
         Append (Result, Ch);
      end loop;
   end Append_Class_Literal;

   function Basic_Bracket_End (Pattern : String; First : Natural) return Natural is
      I : Natural := First + 1;
   begin
      if I <= Pattern'Last and then Pattern (I) in '^' | '!' then
         I := I + 1;
      end if;
      if I <= Pattern'Last and then Pattern (I) = ']' then
         I := I + 1;
      end if;

      while I <= Pattern'Last loop
         if I + 1 <= Pattern'Last
           and then Pattern (I) = '['
           and then Pattern (I + 1) in ':' | '=' | '.'
         then
            declare
               Closing : constant Natural := Bracket_Element_End (Pattern, I + 2, Pattern (I + 1));
            begin
               if Closing /= 0 then
                  I := Closing + 2;
               else
                  I := I + 1;
               end if;
            end;
         elsif Pattern (I) = ']' then
            return I;
         else
            I := I + 1;
         end if;
      end loop;

      return 0;
   end Basic_Bracket_End;

   function Basic_To_Extended (Pattern : String) return String;

   function Translate_Basic_Bracket
     (Pattern : String;
      First   : Natural;
      Last    : Natural;
      Locale  : String) return String
   is
      Class_Text : Unbounded_String;
      Alternatives : String_Vectors.Vector;
      I : Natural := First + 1;
      Negated : Boolean := False;
      Changed : Boolean := False;

      procedure Append_Locale_Range (Low, High : Character) is
         Order : constant String :=
           Posix_Tools.Commands.Text_Helpers.Locale_Collation_Order (Locale, "");
         Low_Pos  : Natural := 0;
         High_Pos : Natural := 0;
      begin
         for J in Order'Range loop
            if Order (J) = Low and then Low_Pos = 0 then
               Low_Pos := J;
            end if;
            if Order (J) = High and then High_Pos = 0 then
               High_Pos := J;
            end if;
         end loop;

         if Low_Pos = 0 or else High_Pos = 0 or else Low_Pos > High_Pos then
            Append_Class_Literal (Class_Text, [1 => Low]);
            Append_Class_Literal (Class_Text, "-");
            Append_Class_Literal (Class_Text, [1 => High]);
         else
            Append_Class_Literal (Class_Text, Order (Low_Pos .. High_Pos));
         end if;
      end Append_Locale_Range;
   begin
      if I <= Last - 1 and then Pattern (I) in '^' | '!' then
         Negated := True;
         Append (Class_Text, Pattern (I));
         I := I + 1;
      end if;

      while I <= Last - 1 loop
         if I + 1 <= Last - 1
           and then Pattern (I) = '['
           and then Pattern (I + 1) in ':' | '=' | '.'
         then
            declare
               Marker  : constant Character := Pattern (I + 1);
               Closing : constant Natural := Bracket_Element_End (Pattern, I + 2, Marker);
            begin
               if Closing = 0 or else Closing + 1 > Last - 1 then
                  Append (Class_Text, Pattern (I));
                  I := I + 1;
               elsif Marker = ':' then
                  Append (Class_Text, Pattern (I .. Closing + 1));
                  I := Closing + 2;
               elsif Marker = '=' then
                  declare
                     Expanded : constant String :=
                       Posix_Tools.Commands.Text_Helpers.Translation_Set_From_Spec
                         (Pattern (I .. Closing + 1), Locale);
                  begin
                     Append_Class_Literal (Class_Text, Expanded);
                     Changed := True;
                     I := Closing + 2;
                  end;
               else
                  declare
                     Symbol : constant String :=
                       Posix_Tools.Commands.Text_Helpers.Translation_Set_From_Spec
                         (Pattern (I .. Closing + 1), Locale);
                  begin
                     if Symbol'Length = 1 then
                        Append_Class_Literal (Class_Text, Symbol);
                     else
                        Alternatives.Append (To_Unbounded_String (Symbol));
                     end if;
                     Changed := True;
                     I := Closing + 2;
                  end;
               end if;
            end;
         else
            if I + 2 <= Last - 1 and then Pattern (I + 1) = '-' then
               Append_Locale_Range (Pattern (I), Pattern (I + 2));
               Changed := True;
               I := I + 3;
            else
               Append (Class_Text, Pattern (I));
               I := I + 1;
            end if;
         end if;
      end loop;

      if not Changed then
         return Pattern (First .. Last);
      elsif Alternatives.Is_Empty then
         return "[" & To_String (Class_Text) & "]";
      elsif Negated then
         return Pattern (First .. Last);
      else
         declare
            Output : Unbounded_String;
         begin
            Append (Output, "(?:");
            if Length (Class_Text) > 0 then
               Append (Output, "[" & To_String (Class_Text) & "]");
            end if;
            for J in 1 .. Natural (Alternatives.Length) loop
               if Length (Class_Text) > 0 or else J > 1 then
                  Append (Output, "|");
               end if;
               Append (Output, Basic_To_Extended (To_String (Alternatives.Element (J))));
            end loop;
            Append (Output, ")");
            return To_String (Output);
         end;
      end if;
   end Translate_Basic_Bracket;

   function Basic_To_Extended (Pattern : String) return String is
      Result : Unbounded_String;
      I : Natural := Pattern'First;
      Current_Locale : constant String := Locale;
   begin
      while I <= Pattern'Last loop
         case Pattern (I) is
            when '[' =>
               declare
                  Closing : constant Natural := Basic_Bracket_End (Pattern, I);
               begin
                  if Closing = 0 then
                     Append (Result, Pattern (I));
                  else
                     Append
                       (Result,
                        Translate_Basic_Bracket (Pattern, I, Closing, Current_Locale));
                     I := Closing;
                  end if;
               end;
            when '\' =>
               if I = Pattern'Last then
                  Append (Result, '\');
               else
                  declare
                     Next : constant Character := Pattern (I + 1);
                  begin
                     case Next is
                        when '(' | ')' =>
                           Append (Result, Next);
                        when '{' =>
                           declare
                              Closing : constant Natural :=
                                Basic_Interval_End (Pattern, I + 2);
                           begin
                              if Closing = 0 then
                                 Append (Result, "\{");
                              else
                                 Append (Result, '{');
                                 if I + 2 <= Closing - 1 then
                                    Append (Result, Pattern (I + 2 .. Closing - 1));
                                 end if;
                                 Append (Result, '}');
                                 I := Closing;
                              end if;
                           end;
                        when '+' | '?' | '|' =>
                           Append (Result, Next);
                        when others =>
                           Append (Result, '\');
                           Append (Result, Next);
                     end case;
                     I := I + 1;
                  end;
               end if;
            when '+' | '?' | '|' | '(' | ')' | '{' | '}' =>
               Append (Result, '\');
               Append (Result, Pattern (I));
            when others =>
               Append (Result, Pattern (I));
         end case;
         I := I + 1;
      end loop;

      return To_String (Result);
   end Basic_To_Extended;

   function Pattern_List_Of (Config : Invocation) return Greplib.Patterns.Pattern_List is
      Result : Greplib.Patterns.Pattern_List;
   begin
      for I in 1 .. Natural (Config.Pattern_Texts.Length) loop
         declare
            Source : constant String := To_String (Config.Pattern_Texts.Element (I));
         begin
         if Config.Fixed_Strings then
            Greplib.Patterns.Append
              (Result,
               Greplib.Patterns.Fixed_String_Pattern (Source));
         else
            Greplib.Patterns.Append
              (Result,
               Greplib.Patterns.Regular_Expression_Pattern
                 (if Config.Regex = Basic_Regular_Expression
                  then Basic_To_Extended (Source)
                  else Source));
         end if;
         end;
      end loop;

      return Result;
   end Pattern_List_Of;

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
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Put_Localized_Error_1
           ("posix_tools.grep.diagnostic.pattern_file.read_failed",
            "path",
            Path,
            "cannot read pattern file '" & Escape_Untrusted (Path) & "'");
         Config.Valid := False;
   end Add_File_Patterns;

   function Needs_File_Prefix (Config : Invocation) return Boolean is
   begin
      if Config.Force_Without_Filename then
         return False;
      elsif Config.Force_With_Filename then
         return True;
      elsif Config.Recursive then
         return True;
      else
         return Natural (Config.Files.Length) > 1;
      end if;
   end Needs_File_Prefix;

   procedure Usage is
      Ignored : constant Boolean :=
        Write_Err
          ("usage: grep [-EFGbciloLqRrvinHhwxs] [-A num] [-B num] [-C num] "
           & "[-m num] [-e pattern] [-f pattern_file] pattern [file...]" & ASCII.LF);
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
           & "  -G           use basic regular expressions (default)" & ASCII.LF
           & "  -E           use extended regular expressions" & ASCII.LF
           & "  -i           ignore ASCII case differences" & ASCII.LF
           & "  -v           select non-matching records" & ASCII.LF
           & "  -w           require a whole-word match" & ASCII.LF
           & "  -A NUM       print NUM records of trailing context" & ASCII.LF
           & "  -B NUM       print NUM records of leading context" & ASCII.LF
           & "  -C NUM       print NUM records of leading and trailing context" & ASCII.LF
           & "  -c           print selected-record counts" & ASCII.LF
           & "  -l, -L       print file names with or without selected records" & ASCII.LF
           & "  -m NUM       stop after NUM selected records per input" & ASCII.LF
           & "  -o           print only matching text" & ASCII.LF
           & "  -q           suppress output and stop after the first match" & ASCII.LF
           & "  -b           prefix output records with byte offsets" & ASCII.LF
           & "  -n           prefix selected records with line numbers" & ASCII.LF
           & "  -H, -h       force or suppress file-name prefixes" & ASCII.LF
           & "  -r, -R       recursively search directory operands" & ASCII.LF
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

      function Option_Argument (Option : Character) return String is
      begin
         if J < Arg'Last then
            declare
               Value : constant String := Arg (J + 1 .. Arg'Last);
            begin
               J := Arg'Last;
               return Value;
            end;
         elsif Index < Ada.Command_Line.Argument_Count then
            Index := Index + 1;
            return Ada.Command_Line.Argument (Index);
         else
            Put_Localized_Error_1
              ("posix_tools.diagnostic.missing_option_argument",
               "option",
               "-" & Option,
               "missing option argument '-" & Option & "'");
            Config.Valid := False;
            return "";
         end if;
      end Option_Argument;

      procedure Set_Context (Option : Character; Value : String) is
         Parsed : Greplib.Wide_Count;
      begin
         begin
            Parsed := Greplib.Wide_Count'Value (Value);
         exception
            when others =>
               Put_Localized_Error_1
                 ("posix_tools.grep.diagnostic.context.invalid",
                  "count",
                  Value,
                  "invalid context count '" & Escape_Untrusted (Value) & "'");
               Config.Valid := False;
               return;
         end;

         case Option is
            when 'A' =>
               Config.After_Context := Parsed;
            when 'B' =>
               Config.Before_Context := Parsed;
            when 'C' =>
               Config.Before_Context := Parsed;
               Config.After_Context := Parsed;
            when others =>
               null;
         end case;
      end Set_Context;

      procedure Set_Maximum_Selected (Value : String) is
      begin
         begin
            Config.Maximum_Selected := Greplib.Wide_Count'Value (Value);
         exception
            when others =>
               Put_Localized_Error_1
                 ("posix_tools.grep.diagnostic.limit.invalid",
                  "count",
                  Value,
                  "invalid selected-record limit '" & Escape_Untrusted (Value) & "'");
               Config.Valid := False;
         end;
      end Set_Maximum_Selected;
   begin
      while J <= Arg'Last loop
         case Arg (J) is
            when 'b' =>
               Config.Byte_Offset := True;
            when 'F' =>
               Config.Fixed_Strings := True;
            when 'G' =>
               Config.Fixed_Strings := False;
               Config.Regex := Basic_Regular_Expression;
            when 'E' =>
               Config.Fixed_Strings := False;
               Config.Regex := Extended_Regular_Expression;
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
            when 'r' | 'R' =>
               Config.Recursive := True;
            when 'v' =>
               Config.Invert_Match := True;
            when 'w' =>
               Config.Whole_Word := True;
            when 'x' =>
               Config.Whole_Record := True;
            when 'o' =>
               Config.Only_Matching := True;
            when 'n' =>
               Config.Line_Number := True;
            when 'H' =>
               Config.Force_With_Filename := True;
            when 'h' =>
               Config.Force_Without_Filename := True;
            when 's' =>
               Config.Suppress_Diagnostics := True;
            when 'A' | 'B' | 'C' =>
               declare
                  Option : constant Character := Arg (J);
                  Value : constant String := Option_Argument (Option);
               begin
                  if not Config.Valid then
                     return;
                  end if;
                  Set_Context (Option, Value);
               end;
            when 'm' =>
               declare
                  Value : constant String := Option_Argument ('m');
               begin
                  if not Config.Valid then
                     return;
                  end if;
                  Set_Maximum_Selected (Value);
               end;
            when 'e' | 'f' =>
               declare
                  Option : constant Character := Arg (J);
                  Value : constant String := Option_Argument (Option);
               begin
                  if not Config.Valid then
                     return;
                  end if;

                  if Option = 'e' then
                     Add_Pattern (Config, Value);
                     Config.Have_Explicit_Pattern := True;
                  else
                     Add_File_Patterns (Config, Value);
                     Config.Have_Explicit_Pattern := True;
                  end if;
               end;
            when others =>
               Put_Localized_Error_1
                 ("posix_tools.diagnostic.option.unknown",
                  "option",
                  "-" & Arg (J),
                  "unknown option '-" & Arg (J) & "'");
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
         Put_Localized_Error
           ("posix_tools.grep.diagnostic.pattern.missing",
            "missing pattern");
         Config.Valid := False;
      end if;
   end Parse;

   function Diagnostic_Detail
     (Item : Greplib.Diagnostics.Diagnostic) return String is
      Result : Unbounded_String;
   begin
      if Greplib.Diagnostics.Message (Item) /= "" then
         Append (Result, Escape_Untrusted (Greplib.Diagnostics.Message (Item)));
      end if;
      if Greplib.Diagnostics.Has_Path (Item) then
         Append (Result, " path=" & Escape_Untrusted (Greplib.Diagnostics.Path (Item)));
      end if;
      if Greplib.Diagnostics.Has_Filesystem_Operation (Item) then
         Append
           (Result,
            " op=" & Escape_Untrusted (Greplib.Diagnostics.Filesystem_Operation (Item)));
      end if;
      if Greplib.Diagnostics.Has_Record_Number (Item) then
         Append (Result, " record=" & Count_Image (Greplib.Diagnostics.Record_No (Item)));
      end if;
      if Greplib.Diagnostics.Has_Native_Error (Item) then
         Append
           (Result,
            " native=" & Escape_Untrusted (Integer'Image (Greplib.Diagnostics.Native_Error (Item))));
      end if;
      if Greplib.Diagnostics.Has_Exception_Name (Item) then
         Append
           (Result,
            " exception=" & Escape_Untrusted (Greplib.Diagnostics.Exception_Name (Item)));
      end if;
      if Greplib.Diagnostics.Has_Numeric_Limit (Item) then
         Append (Result, " limit=" & Count_Image (Greplib.Diagnostics.Numeric_Limit (Item)));
      end if;
      if Greplib.Diagnostics.Has_Observed_Size (Item) then
         Append
           (Result, " observed=" & Count_Image (Greplib.Diagnostics.Observed_Size (Item)));
      end if;

      return To_String (Result);
   end Diagnostic_Detail;

   function Localized_Diagnostic
     (Item : Greplib.Diagnostics.Diagnostic) return String
   is
      Identifier : constant String :=
        Greplib.Diagnostics.Identifier (Greplib.Diagnostics.Code (Item));
      Detail : constant String := Diagnostic_Detail (Item);
      Default : constant String :=
        Identifier & (if Detail = "" then "" else ": " & Detail);
   begin
      return Localized_1
        ("posix_tools.grep.diagnostic." & Identifier,
         "detail",
         Detail,
         Default);
   end Localized_Diagnostic;

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
            Text : constant String := Localized_Diagnostic (Diagnostic);
            Ignored : constant Boolean := Write_Err ("grep: " & Text & ASCII.LF);
         begin
            null;
         end;
      end loop;
   end Report_Diagnostics;

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
      Last_Group : Greplib.Wide_Count := 0;

      procedure Render_Record
        (Event : Greplib.Events.Search_Event;
         Separator : Character) is
         Content : constant String :=
           Greplib.Byte_Strings.To_String (Greplib.Events.Content (Event));

         function Prefix
           (Output_Separator : Character;
            Offset : Greplib.Byte_Offset := Greplib.Events.Record_Byte_Offset (Event))
            return String
         is
            Result : Unbounded_String;
         begin
            if Prefix_File then
               Append (Result, Source_Name (File_Name, Event) & Output_Separator);
            end if;
            if Config.Line_Number then
               Append
                 (Result,
                  Count_Image (Greplib.Events.Record_No (Event)) & Output_Separator);
            end if;
            if Config.Byte_Offset then
               Append (Result, Count_Image (Offset) & Output_Separator);
            end if;

            return To_String (Result);
         end Prefix;
      begin
         if Config.Only_Matching
           and then Greplib.Events.Kind (Event) = Greplib.Events.Selected_Record
         then
            for I in 1 .. Natural (Greplib.Events.Spans (Event).Length) loop
               declare
                  Span : constant Greplib.Events.Match_Span :=
                    Greplib.Events.Spans (Event).Element (I);
               begin
                  if Span.Last_Byte_Exclusive > Span.First_Byte then
                     declare
                        First : constant Positive :=
                          Content'First + Natural (Span.First_Byte);
                        Last : constant Natural :=
                          Content'First + Natural (Span.Last_Byte_Exclusive) - 1;
                        Offset : constant Greplib.Byte_Offset :=
                          Greplib.Events.Record_Byte_Offset (Event) + Span.First_Byte;
                        Ignored : constant Boolean :=
                          Write_Out (Prefix (Separator, Offset) & Content (First .. Last) & ASCII.LF);
                     begin
                        null;
                     end;
                  end if;
               end;
            end loop;
         else
            declare
               Ignored : constant Boolean :=
                 Write_Out (Prefix (Separator) & Content & ASCII.LF);
            begin
               null;
            end;
         end if;
      end Render_Record;
   begin
      for I in 1 .. Natural (Result.Events.Length) loop
         declare
            Event : constant Greplib.Events.Search_Event := Result.Events.Element (I);
         begin
            case Greplib.Events.Kind (Event) is
               when Greplib.Events.Selected_Record =>
                  Render_Record (Event, ':');
                  Last_Group := Greplib.Events.Group_Number (Event);
               when Greplib.Events.Context_Record =>
                  if Last_Group /= 0
                    and then Greplib.Events.Group_Number (Event) /= Last_Group
                  then
                     declare
                        Ignored : constant Boolean := Write_Out ("--" & ASCII.LF);
                     begin
                        null;
                     end;
                  end if;
                  Render_Record (Event, '-');
                  Last_Group := Greplib.Events.Group_Number (Event);
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
      Options.Context.Before := Config.Before_Context;
      Options.Context.After := Config.After_Context;
      Options.Maximum_Selected_Records := Config.Maximum_Selected;
      if Config.Only_Matching then
         Options.Spans := Greplib.Options.All_Spans;
      elsif Config.Byte_Offset then
         Options.Spans := Greplib.Options.First_Span;
      end if;
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

   procedure Search_Paths
     (Config : Invocation;
      Set : Greplib.Patterns.Compiled_Pattern_Set;
      Had_Selected : in out Boolean;
      Had_Error : in out Boolean) is
      Roots : Greplib.Paths.Path_List;
      Options : Greplib.Options.Search_Options;
      Directory_Options : Greplib.Directories.Directory_Search_Options;
      Collection : Greplib.Collected.Collection_Options;
      Result : Greplib.Collected.Collected_Result;
   begin
      if Config.Files.Is_Empty then
         Greplib.Paths.Append (Roots, Greplib.Paths.To_Path ("."));
      else
         for I in 1 .. Natural (Config.Files.Length) loop
            Greplib.Paths.Append
              (Roots, Greplib.Paths.To_Path (To_String (Config.Files.Element (I))));
         end loop;
      end if;

      Apply_Mode (Config, Options);
      Directory_Options.Recursive := True;
      Collection.On_Limit := Greplib.Collected.Continue_Without_Collecting;
      Greplib.Collected.Search_Paths
        (Roots, Set, Options, Directory_Options, Collection, Result);
      Render_Events (Config, "", Result);
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
   end Search_Paths;

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
      Compile_Options.Whole_Word := Config.Whole_Word;
      Set := Greplib.Patterns.Compile (Pattern_List_Of (Config), Compile_Options);
      if not Greplib.Patterns.Is_Usable (Set) then
         Report_Diagnostics (Greplib.Patterns.Diagnostics (Set), Config.Suppress_Diagnostics);
         Posix_Tools.Process_Entry.Set_Exit_Status (2);
         return;
      end if;

      declare
         Had_Selected : Boolean := False;
         Had_Error : Boolean := False;
      begin
         if Config.Recursive then
            Search_Paths (Config, Set, Had_Selected, Had_Error);
         elsif Config.Files.Is_Empty then
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
      Put_Localized_Error_1
        ("posix_tools.grep.diagnostic.internal_error",
         "detail",
         Ada.Exceptions.Exception_Name (Error),
         "internal error: " & Escape_Untrusted (Ada.Exceptions.Exception_Name (Error)));
      Posix_Tools.Process_Entry.Set_Exit_Status (2);
end Grep;
