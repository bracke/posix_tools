with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Streams.Bytes;

package body Posix_Tools.Commands.Grep.Options is
   use type Ada.Streams.Stream_Element_Offset;

   package Grep_Patterns renames Posix_Tools.Commands.Grep.Patterns;

   --  Append the patterns of the pattern file Path, standard input for "-",
   --  to Config; False, with its diagnostic written, when it cannot be read.
   function Add_File_Patterns
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Config  : in out Invocation;
      Path    : String) return Boolean;

   --  Text as a count, or False when it is not a decimal number.
   function Parse_Count (Text : String; Value : out Greplib.Wide_Count) return Boolean;

   function Add_File_Patterns
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Config  : in out Invocation;
      Path    : String) return Boolean
   is
      Data : Ada.Strings.Unbounded.Unbounded_String;
      Ok   : Boolean := True;

      --  Gather one chunk of the file.
      procedure Gather
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);

      procedure Gather
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
         pragma Unreferenced (Stop);
      begin
         Ada.Strings.Unbounded.Append (Data, Posix_Tools.Streams.Bytes.To_String (Buffer, Last));
      end Gather;

      procedure Read_File is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk (Action => Gather);
   begin
      if Path = "-" then
         declare
            Buffer : Ada.Streams.Stream_Element_Array (1 .. 16 * 1024);
            Last   : Ada.Streams.Stream_Element_Offset;
         begin
            loop
               if not Context.Try_Read_Standard_Input (Buffer, Last) then
                  Ok := False;
                  exit;
               end if;
               exit when Last < Buffer'First;
               Ada.Strings.Unbounded.Append (Data, Posix_Tools.Streams.Bytes.To_String (Buffer, Last));
            end loop;
         end;
      else
         Read_File (Path, Ok);
      end if;

      if not Ok then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context,
            "posix_tools.grep.diagnostic.pattern_file.read_failed",
            "path",
            (if Path = "-" then Posix_Tools.Commands.Helpers.Standard_Input_Name (Context) else Path),
            "cannot read pattern file '{path}'");
         return False;
      end if;

      Grep_Patterns.Append_Pattern_File (Config.Pattern_Texts, Ada.Strings.Unbounded.To_String (Data));
      return True;
   end Add_File_Patterns;

   function Needs_File_Prefix (Config : Invocation) return Boolean is
   begin
      if Config.Force_Without_Filename then
         return False;
      elsif Config.Force_With_Filename or else Config.Recursive then
         return True;
      else
         return Natural (Config.Files.Length) > 1;
      end if;
   end Needs_File_Prefix;

   procedure Parse
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Config  : out Invocation;
      Outcome : out Parse_Outcome)
   is
      End_Options       : Boolean := False;
      Have_Pattern_List    : Boolean := False;
      Have_Pattern_Operand : Boolean := False;
      Index                : Positive := 1;

      --  Parse the option cluster Arg, which may take the next argument.
      procedure Parse_Short (Arg : String);

      --  Report the usage diagnostic Key with Value filling {Name}.
      procedure Usage_Diagnostic (Key, Name, Value, Default : String);

      procedure Parse_Short (Arg : String) is
         J : Positive := Arg'First + 1;

         --  The argument of Option: the rest of Arg, else the next argument.
         function Option_Argument (Option : Character; Found : out Boolean) return String;

         --  Set Target from Value, or report Key.
         procedure Set_Count
           (Target  : in out Greplib.Wide_Count;
            Value   : String;
            Key     : String;
            Default : String);

         function Option_Argument (Option : Character; Found : out Boolean) return String is
         begin
            Found := True;
            if J < Arg'Last then
               declare
                  Value : constant String := Arg (J + 1 .. Arg'Last);
               begin
                  J := Arg'Last;
                  return Value;
               end;
            elsif Index < Context.Argument_Count then
               Index := Index + 1;
               return Context.Argument (Index);
            else
               Usage_Diagnostic
                 ("posix_tools.diagnostic.missing_option_argument",
                  "option",
                  "-" & Option,
                  "missing option argument '{option}'");
               Found := False;
               return "";
            end if;
         end Option_Argument;

         procedure Set_Count
           (Target  : in out Greplib.Wide_Count;
            Value   : String;
            Key     : String;
            Default : String)
         is
            Parsed : Greplib.Wide_Count;
         begin
            if Parse_Count (Value, Parsed) then
               Target := Parsed;
            else
               Usage_Diagnostic (Key, "count", Value, Default);
            end if;
         end Set_Count;
      begin
         while J <= Arg'Last and then Outcome = Search loop
            case Arg (J) is
               when 'b' => Config.Byte_Offset := True;
               when 'F' => Config.Fixed_Strings := True;
               when 'G' =>
                  Config.Fixed_Strings := False;
                  Config.Regex := Basic_Regular_Expression;
               when 'E' =>
                  Config.Fixed_Strings := False;
                  Config.Regex := Extended_Regular_Expression;
               when 'c' => Config.Count_Only := True;
               when 'i' => Config.Ignore_Case := True;
               when 'l' => Config.List_With_Matches := True;
               when 'L' => Config.List_Without_Matches := True;
               when 'q' => Config.Quiet := True;
               when 'r' | 'R' => Config.Recursive := True;
               when 'v' => Config.Invert_Match := True;
               when 'w' => Config.Whole_Word := True;
               when 'x' => Config.Whole_Record := True;
               when 'o' => Config.Only_Matching := True;
               when 'n' => Config.Line_Number := True;
               when 'H' => Config.Force_With_Filename := True;
               when 'h' => Config.Force_Without_Filename := True;
               when 's' => Config.Suppress_Diagnostics := True;
               when 'A' | 'B' | 'C' | 'm' | 'e' | 'f' =>
                  declare
                     Option : constant Character := Arg (J);
                     Found  : Boolean;
                     Value  : constant String := Option_Argument (Option, Found);
                  begin
                     if Found then
                        case Option is
                           when 'A' =>
                              Set_Count
                                (Config.After_Context, Value, "posix_tools.grep.diagnostic.context.invalid",
                                 "invalid context count '{count}'");
                           when 'B' =>
                              Set_Count
                                (Config.Before_Context, Value, "posix_tools.grep.diagnostic.context.invalid",
                                 "invalid context count '{count}'");
                           when 'C' =>
                              Set_Count
                                (Config.Before_Context, Value, "posix_tools.grep.diagnostic.context.invalid",
                                 "invalid context count '{count}'");
                              Config.After_Context := Config.Before_Context;
                           when 'm' =>
                              Set_Count
                                (Config.Maximum_Selected, Value, "posix_tools.grep.diagnostic.limit.invalid",
                                 "invalid selected-record limit '{count}'");
                           when 'e' =>
                              Grep_Patterns.Append_Pattern_List (Config.Pattern_Texts, Value);
                              Have_Pattern_List := True;
                           when others =>
                              Have_Pattern_List := True;
                              if not Add_File_Patterns (Context, Config, Value) then
                                 Outcome := Pattern_File_Failure;
                              end if;
                        end case;
                     end if;
                  end;
               when others =>
                  Usage_Diagnostic
                    ("posix_tools.diagnostic.option.unknown",
                     "option",
                     "-" & Arg (J),
                     "unknown option '{option}'");
            end case;
            J := J + 1;
         end loop;
      end Parse_Short;

      procedure Usage_Diagnostic (Key, Name, Value, Default : String) is
      begin
         Posix_Tools.Commands.Helpers.Operational_Error (Context, Key, Name, Value, Default);
         Outcome := Usage_Failure;
      end Usage_Diagnostic;
   begin
      Config := (others => <>);
      Outcome := Search;

      while Index <= Context.Argument_Count and then Outcome = Search loop
         declare
            Arg : constant String := Context.Argument (Index);
         begin
            if not End_Options and then Arg = "--" then
               End_Options := True;
            elsif not End_Options and then Arg = "--help" then
               Outcome := Show_Help;
            elsif not End_Options and then Arg = "--version" then
               Outcome := Show_Version;
            elsif not End_Options and then Arg'Length > 1 and then Arg (Arg'First) = '-' then
               Parse_Short (Arg);
            elsif Have_Pattern_List or else Have_Pattern_Operand then
               Config.Files.Append (Arg);
            else
               Grep_Patterns.Append_Pattern_List (Config.Pattern_Texts, Arg);
               Have_Pattern_Operand := True;
            end if;
         end;
         Index := Index + 1;
      end loop;

      if Outcome = Search and then not Have_Pattern_List and then not Have_Pattern_Operand then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.grep.diagnostic.pattern.missing", "missing pattern");
         Outcome := Usage_Failure;
      end if;
   end Parse;

   function Parse_Count (Text : String; Value : out Greplib.Wide_Count) return Boolean is
   begin
      Value := 0;
      if Text = "" then
         return False;
      end if;

      for Ch of Text loop
         if Ch not in '0' .. '9' then
            return False;
         end if;
      end loop;

      Value := Greplib.Wide_Count'Value (Text);
      return True;
   exception
      when Constraint_Error =>
         return False;
   end Parse_Count;
end Posix_Tools.Commands.Grep.Options;
