with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Greplib.Diagnostics;
with Greplib.Directories;
with Greplib.Files;
with Greplib.Options;
with Greplib.Paths;
with Greplib.Patterns;
with Greplib.Results;
with Posix_Tools.Commands.Grep.Input;
with Posix_Tools.Commands.Grep.Options;
with Posix_Tools.Commands.Grep.Patterns;
with Posix_Tools.Commands.Grep.Rendering;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Help;
with Posix_Tools.Localization;
with Posix_Tools.Version;

package body Posix_Tools.Commands.Grep is
   use type Greplib.Wide_Count;
   use type Posix_Tools.Commands.Grep.Options.Parse_Outcome;
   use type Posix_Tools.Commands.Grep.Options.Regex_Mode;

   package Grep_Options renames Posix_Tools.Commands.Grep.Options;

   --  A regular expression no line matches: what an empty pattern list,
   --  from an empty -f file, is searched as. greplib takes no empty list.
   Matches_Nothing : constant String := "a^";

   --  Set Options from what Config asks for.
   procedure Apply_Mode (Config : Grep_Options.Invocation; Options : in out Greplib.Options.Search_Options);

   --  Item's fields after its identifier, for its diagnostic.
   function Diagnostic_Detail (Item : Greplib.Diagnostics.Diagnostic) return String;

   function Image (Value : Greplib.Wide_Count) return String;

   --  Item as a localized diagnostic text.
   function Localized_Diagnostic
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Item    : Greplib.Diagnostics.Diagnostic) return String;

   --  The pattern list of Config as greplib declares it.
   function Pattern_List_Of
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Config  : Grep_Options.Invocation) return Greplib.Patterns.Pattern_List;

   --  Write each diagnostic of List unless Suppress.
   procedure Report_Diagnostics
     (Context  : in out Posix_Tools.Commands.Contexts.Context'Class;
      List     : Greplib.Diagnostics.Diagnostic_List;
      Suppress : Boolean);

   --  Search what Config names with Set; True when a line was selected.
   procedure Search
     (Context      : in out Posix_Tools.Commands.Contexts.Context'Class;
      Config       : Grep_Options.Invocation;
      Set          : Greplib.Patterns.Compiled_Pattern_Set;
      Had_Selected : out Boolean;
      Had_Error    : out Boolean;
      Write_Failed : out Boolean);

   procedure Write_Help (Context : in out Posix_Tools.Commands.Contexts.Context'Class);

   procedure Write_Usage (Context : in out Posix_Tools.Commands.Contexts.Context'Class);

   procedure Write_Version (Context : in out Posix_Tools.Commands.Contexts.Context'Class);

   procedure Apply_Mode (Config : Grep_Options.Invocation; Options : in out Greplib.Options.Search_Options) is
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

   function Diagnostic_Detail (Item : Greplib.Diagnostics.Diagnostic) return String is
      use Ada.Strings.Unbounded;

      Result : Unbounded_String;

      --  Text escaped for a diagnostic.
      function Shown (Text : String) return String;

      function Shown (Text : String) return String is
      begin
         return Posix_Tools.Commands.Helpers.Escape_Untrusted (Text);
      end Shown;
   begin
      if Greplib.Diagnostics.Message (Item) /= "" then
         Append (Result, Shown (Greplib.Diagnostics.Message (Item)));
      end if;
      if Greplib.Diagnostics.Has_Path (Item) then
         Append (Result, " path=" & Shown (Greplib.Diagnostics.Path (Item)));
      end if;
      if Greplib.Diagnostics.Has_Filesystem_Operation (Item) then
         Append (Result, " op=" & Shown (Greplib.Diagnostics.Filesystem_Operation (Item)));
      end if;
      if Greplib.Diagnostics.Has_Record_Number (Item) then
         Append (Result, " record=" & Image (Greplib.Diagnostics.Record_No (Item)));
      end if;
      if Greplib.Diagnostics.Has_Native_Error (Item) then
         Append (Result, " native=" & Shown (Integer'Image (Greplib.Diagnostics.Native_Error (Item))));
      end if;
      if Greplib.Diagnostics.Has_Exception_Name (Item) then
         Append (Result, " exception=" & Shown (Greplib.Diagnostics.Exception_Name (Item)));
      end if;
      if Greplib.Diagnostics.Has_Numeric_Limit (Item) then
         Append (Result, " limit=" & Image (Greplib.Diagnostics.Numeric_Limit (Item)));
      end if;
      if Greplib.Diagnostics.Has_Observed_Size (Item) then
         Append (Result, " observed=" & Image (Greplib.Diagnostics.Observed_Size (Item)));
      end if;

      return To_String (Result);
   end Diagnostic_Detail;

   function Image (Value : Greplib.Wide_Count) return String is
      Text : constant String := Greplib.Wide_Count'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   function Localized_Diagnostic
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Item    : Greplib.Diagnostics.Diagnostic) return String
   is
      Identifier : constant String := Greplib.Diagnostics.Identifier (Greplib.Diagnostics.Code (Item));
      Detail     : constant String := Diagnostic_Detail (Item);
   begin
      return Posix_Tools.Localization.Text_1
        (Context.Effective_Locale,
         "posix_tools.grep.diagnostic." & Identifier,
         "detail",
         Detail,
         Identifier & (if Detail = "" then "" else ": " & Detail));
   end Localized_Diagnostic;

   function Pattern_List_Of
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Config  : Grep_Options.Invocation) return Greplib.Patterns.Pattern_List
   is
      Result : Greplib.Patterns.Pattern_List;
      Locale : constant String := Context.Category_Locale (Posix_Tools.Commands.Contexts.Collation);
   begin
      if Config.Pattern_Texts.Is_Empty then
         Greplib.Patterns.Append (Result, Greplib.Patterns.Regular_Expression_Pattern (Matches_Nothing));
      end if;

      for Source of Config.Pattern_Texts loop
         --  The empty pattern matches every line, in every syntax; greplib
         --  takes it only as a fixed string.
         if Config.Fixed_Strings or else Source = "" then
            Greplib.Patterns.Append (Result, Greplib.Patterns.Fixed_String_Pattern (Source));
         elsif Config.Regex = Grep_Options.Basic_Regular_Expression then
            Greplib.Patterns.Append
              (Result,
               Greplib.Patterns.Regular_Expression_Pattern
                 (Posix_Tools.Commands.Grep.Patterns.Basic_To_Extended (Source, Locale)));
         else
            Greplib.Patterns.Append (Result, Greplib.Patterns.Regular_Expression_Pattern (Source));
         end if;
      end loop;

      return Result;
   end Pattern_List_Of;

   procedure Report_Diagnostics
     (Context  : in out Posix_Tools.Commands.Contexts.Context'Class;
      List     : Greplib.Diagnostics.Diagnostic_List;
      Suppress : Boolean) is
   begin
      if Suppress then
         return;
      end if;

      for I in 1 .. Natural (Greplib.Diagnostics.Length (List)) loop
         Context.Put_Error_Line ("grep: " & Localized_Diagnostic (Context, Greplib.Diagnostics.Element (List, I)));
      end loop;
   end Report_Diagnostics;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Config  : Grep_Options.Invocation;
      Outcome : Grep_Options.Parse_Outcome;
   begin
      Result.Status := Posix_Tools.Exit_Status.Success;

      if Context.Argument_Count = 1 and then Context.Argument (1) = "--posix-tools-identify" then
         Posix_Tools.Help.Render_Identity (Context, "grep");
         if Context.Output_Failed then
            Result.Status := Trouble;
         end if;
         return;
      end if;

      Grep_Options.Parse (Context, Config, Outcome);
      case Outcome is
         when Grep_Options.Show_Help =>
            Write_Help (Context);
            if Context.Output_Failed then
               Result.Status := Trouble;
            end if;
            return;
         when Grep_Options.Show_Version =>
            Write_Version (Context);
            if Context.Output_Failed then
               Result.Status := Trouble;
            end if;
            return;
         when Grep_Options.Usage_Failure =>
            Write_Usage (Context);
            Result.Status := Trouble;
            return;
         when Grep_Options.Pattern_File_Failure =>
            Result.Status := Trouble;
            return;
         when Grep_Options.Search =>
            null;
      end case;

      declare
         Compile_Options : Greplib.Patterns.Compilation_Options;
         Set             : Greplib.Patterns.Compiled_Pattern_Set;
         Had_Selected    : Boolean;
         Had_Error       : Boolean;
         Write_Failed    : Boolean;
      begin
         Compile_Options.Case_Insensitive := Config.Ignore_Case;
         Compile_Options.Whole_Record := Config.Whole_Record;
         Compile_Options.Whole_Word := Config.Whole_Word;
         Set := Greplib.Patterns.Compile (Pattern_List_Of (Context, Config), Compile_Options);
         if not Greplib.Patterns.Is_Usable (Set) then
            Report_Diagnostics (Context, Greplib.Patterns.Diagnostics (Set), Config.Suppress_Diagnostics);
            Result.Status := Trouble;
            return;
         end if;

         Search (Context, Config, Set, Had_Selected, Had_Error, Write_Failed);

         if Write_Failed then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.grep.diagnostic.output.write_failed", "cannot write standard output");
            Result.Status := Trouble;
         elsif Config.Quiet and then Had_Selected then
            --  A selected line makes -q succeed even after an error.
            Result.Status := Posix_Tools.Exit_Status.Success;
         elsif Had_Error then
            Result.Status := Trouble;
         elsif Had_Selected then
            Result.Status := Posix_Tools.Exit_Status.Success;
         else
            Result.Status := No_Lines_Selected;
         end if;
      end;
   exception
      when Error : others =>
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context,
            "posix_tools.grep.diagnostic.internal_error",
            "detail",
            Ada.Exceptions.Exception_Name (Error),
            "internal error: {detail}");
         Result.Status := Trouble;
   end Run;

   procedure Search
     (Context      : in out Posix_Tools.Commands.Contexts.Context'Class;
      Config       : Grep_Options.Invocation;
      Set          : Greplib.Patterns.Compiled_Pattern_Set;
      Had_Selected : out Boolean;
      Had_Error    : out Boolean;
      Write_Failed : out Boolean)
   is
      Options : Greplib.Options.Search_Options;
      Sink    : Posix_Tools.Commands.Grep.Rendering.Output_Sink (Context'Access);

      --  Fold the outcome of one search into the results.
      procedure Account (Outcome : Greplib.Results.Search_Outcome);

      --  Search one file operand, standard input for "-".
      procedure Search_One (File_Name : String; Sequence : Greplib.Source_Sequence);

      procedure Account (Outcome : Greplib.Results.Search_Outcome) is
      begin
         Posix_Tools.Commands.Grep.Rendering.Flush (Sink);
         Report_Diagnostics (Context, Greplib.Results.Diagnostics (Outcome), Config.Suppress_Diagnostics);
         if Greplib.Results.Selected_Record_Count (Greplib.Results.Summary (Outcome)) > 0 then
            Had_Selected := True;
         end if;
         case Greplib.Results.Status (Outcome) is
            when Greplib.Results.Completed =>
               null;
            when Greplib.Results.Completed_With_Recoverable_Errors
               | Greplib.Results.Cancelled
               | Greplib.Results.Failed =>
               Had_Error := True;
         end case;
      end Account;

      procedure Search_One (File_Name : String; Sequence : Greplib.Source_Sequence) is
         Outcome : Greplib.Results.Search_Outcome;
      begin
         if File_Name = "-" then
            Posix_Tools.Commands.Grep.Rendering.Begin_Search
              (Sink, Posix_Tools.Commands.Grep.Rendering.Standard_Input_Label);
            declare
               Stream : Posix_Tools.Commands.Grep.Input.Standard_Input_Stream (Context'Access);
            begin
               Greplib.Files.Search_Stream (Stream, Set, Options, Sink, Outcome, Sequence => Sequence);
            end;
         else
            Posix_Tools.Commands.Grep.Rendering.Begin_Search (Sink, File_Name);
            Greplib.Files.Search_File
              (Greplib.Paths.To_Path (File_Name), Set, Options, Sink, Outcome, Sequence => Sequence);
         end if;
         Account (Outcome);
      end Search_One;
   begin
      Had_Selected := False;
      Had_Error := False;
      Apply_Mode (Config, Options);
      Posix_Tools.Commands.Grep.Rendering.Configure
        (Sink,
         (Prefix_File          => Grep_Options.Needs_File_Prefix (Config),
          Line_Number          => Config.Line_Number,
          Byte_Offset          => Config.Byte_Offset,
          Only_Matching        => Config.Only_Matching,
          List_Without_Matches => Config.List_Without_Matches,
          Flush_Each_Record    => Context.Standard_Output_Is_Terminal));

      if Config.Recursive then
         declare
            Roots             : Greplib.Paths.Path_List;
            Directory_Options : Greplib.Directories.Directory_Search_Options;
            Outcome           : Greplib.Results.Search_Outcome;
         begin
            if Config.Files.Is_Empty then
               Greplib.Paths.Append (Roots, Greplib.Paths.To_Path ("."));
            else
               for File_Name of Config.Files loop
                  Greplib.Paths.Append (Roots, Greplib.Paths.To_Path (File_Name));
               end loop;
            end if;
            Directory_Options.Recursive := True;
            Posix_Tools.Commands.Grep.Rendering.Begin_Search (Sink, "");
            Greplib.Directories.Search_Paths (Roots, Set, Options, Directory_Options, Sink, Outcome);
            Account (Outcome);
         end;
      elsif Config.Files.Is_Empty then
         Search_One ("-", 1);
      else
         for I in 1 .. Natural (Config.Files.Length) loop
            Search_One (Config.Files.Element (I), Greplib.Source_Sequence (I));
            --  -q is answered by the first selected line.
            exit when Config.Quiet and then Had_Selected;
            exit when Posix_Tools.Commands.Grep.Rendering.Output_Failed (Sink);
         end loop;
      end if;

      Posix_Tools.Commands.Grep.Rendering.Flush (Sink);
      Write_Failed := Posix_Tools.Commands.Grep.Rendering.Output_Failed (Sink);
   end Search;

   procedure Write_Help (Context : in out Posix_Tools.Commands.Contexts.Context'Class) is
      LF : constant Character := ASCII.LF;
   begin
      Context.Put
        ("Usage: grep [OPTION]... PATTERN [FILE]..." & LF
         & "Search FILEs or standard input for records matching PATTERN." & LF
         & LF
         & "  -e PATTERN   use PATTERN as a search pattern" & LF
         & "  -f FILE      read patterns from FILE" & LF
         & "  -F           treat patterns as fixed strings" & LF
         & "  -G           use basic regular expressions (default)" & LF
         & "  -E           use extended regular expressions" & LF
         & "  -i           ignore ASCII case differences" & LF
         & "  -v           select non-matching records" & LF
         & "  -w           require a whole-word match" & LF
         & "  -A NUM       print NUM records of trailing context" & LF
         & "  -B NUM       print NUM records of leading context" & LF
         & "  -C NUM       print NUM records of leading and trailing context" & LF
         & "  -c           print selected-record counts" & LF
         & "  -l, -L       print file names with or without selected records" & LF
         & "  -m NUM       stop after NUM selected records per input" & LF
         & "  -o           print only matching text" & LF
         & "  -q           suppress output and stop after the first match" & LF
         & "  -b           prefix output records with byte offsets" & LF
         & "  -n           prefix selected records with line numbers" & LF
         & "  -H, -h       force or suppress file-name prefixes" & LF
         & "  -r, -R       recursively search directory operands" & LF
         & "  -x           require a whole-record match" & LF
         & "  -s           suppress input diagnostics" & LF
         & "      --help, --version, --posix-tools-identify" & LF);
   end Write_Help;

   procedure Write_Usage (Context : in out Posix_Tools.Commands.Contexts.Context'Class) is
   begin
      Context.Put_Error_Line
        ("usage: grep [-EFGbciloLqRrvinHhwxs] [-A num] [-B num] [-C num] "
         & "[-m num] [-e pattern] [-f pattern_file] pattern [file...]");
   end Write_Usage;

   procedure Write_Version (Context : in out Posix_Tools.Commands.Contexts.Context'Class) is
   begin
      Context.Put
        ("grep " & Posix_Tools.Version.Version_String & ASCII.LF
         & "engine greplib" & ASCII.LF
         & "license MIT" & ASCII.LF);
   end Write_Version;
end Posix_Tools.Commands.Grep;
