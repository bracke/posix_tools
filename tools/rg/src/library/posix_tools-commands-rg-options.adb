with Posix_Tools.Commands.Rg.Encodings;
with Regexp;

package body Posix_Tools.Commands.Rg.Options is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Commands.Rg.Rendering.Result_Mode;
   use type Posix_Tools.Commands.Rg.Input.Read_Outcome;

   Inline_Pattern : constant Character := 'E';
   File_Pattern   : constant Character := 'F';

   procedure Parse
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Config  : out Invocation;
      Outcome : out Parse_Outcome)
   is
      Operands             : Posix_Tools.Arguments.Vector;
      Has_Explicit_Pattern : Boolean := False;
      Before_Context_Set   : Boolean := False;
      After_Context_Set    : Boolean := False;
      Options_Ended        : Boolean := False;
      Index                : Positive := 1;

      procedure Fail (Text : String);
      procedure Set_Max_Count (Text : String);
      procedure Set_Max_Depth (Text : String);
      procedure Set_Max_File_Size (Text : String);
      procedure Set_Threads (Text : String);
      procedure Set_Sort (Text : String; Descending : Boolean);
      procedure Set_Color (Text : String);
      procedure Add_Color_Rule (Text : String);
      procedure Set_Context_Count
        (Text        : String;
         Option_Name : String;
         Before      : Boolean;
         After       : Boolean;
         Specific    : Boolean);
      procedure Take_Type (Name : String; Include : Boolean);
      procedure Take_Pattern_File (Path : String);
      procedure Take_Pattern (Text : String);
      function Load_Pattern_File (Path : String) return Boolean;

      procedure Fail (Text : String) is
      begin
         Config.Error_Text.Append
           (Posix_Tools.Commands.Rg.Diagnostics.Localized (Context, Text));
         Outcome := Parse_Error;
      end Fail;

      procedure Set_Color (Text : String) is
      begin
         if Text = "auto" then
            Config.Color_Output := Posix_Tools.Commands.Rg.Rendering.Color_Automatic;
         elsif Text in "always" | "ansi" then
            Config.Color_Output := Posix_Tools.Commands.Rg.Rendering.Color_Always;
         elsif Text = "never" then
            Config.Color_Output := Posix_Tools.Commands.Rg.Rendering.Color_Never;
         else
            Fail ("invalid value for --color: " & Text);
         end if;
      end Set_Color;

      procedure Add_Color_Rule (Text : String) is
         Success : Boolean;
         Message : Unbounded_String;
      begin
         Posix_Tools.Commands.Rg.Colors.Apply
           (Config.Colors, Text, Success, Message);
         if not Success then
            Fail (To_String (Message));
         end if;
      end Add_Color_Rule;

      procedure Take_Pattern (Text : String) is
      begin
         Config.Pattern_Sources.Append (Inline_Pattern & Text);
         Has_Explicit_Pattern := True;
      end Take_Pattern;

      procedure Take_Pattern_File (Path : String) is
      begin
         Config.Pattern_Sources.Append (File_Pattern & Path);
         Has_Explicit_Pattern := True;
      end Take_Pattern_File;

      procedure Take_Type (Name : String; Include : Boolean) is
         Known : constant Boolean :=
           (if Include
            then Posix_Tools.Commands.Rg.Types.Include_Type (Config.File_Types, Name)
            else Posix_Tools.Commands.Rg.Types.Exclude_Type (Config.File_Types, Name));
      begin
         if not Known then
            Fail ("unrecognized file type: " & Name);
         end if;
      end Take_Type;

      function Load_Pattern_File (Path : String) return Boolean is
         Reader : Posix_Tools.Commands.Rg.Input.Reader;
         Opened : Boolean;
         Closed : Boolean;
      begin
         Posix_Tools.Commands.Rg.Input.Open
           (Reader, Path, Posix_Tools.Commands.Rg.Input.No_Encoding, Opened);
         if not Opened then
            Fail ("cannot read pattern file: " & Path);
            return False;
         end if;

         loop
            declare
               Line       : Unbounded_String;
               Terminated : Boolean;
               Status     : Posix_Tools.Commands.Rg.Input.Read_Outcome;
            begin
               Posix_Tools.Commands.Rg.Input.Next
                 (Reader, Context, Line, Terminated, Status);
               pragma Unreferenced (Terminated);

               case Status is
                  when Posix_Tools.Commands.Rg.Input.Line_Available =>
                     declare
                        Text : constant String := To_String (Line);
                     begin
                        if Text'Length > 0 and then Text (Text'Last) = ASCII.CR then
                           Config.Pattern_Texts.Append (Text (Text'First .. Text'Last - 1));
                        else
                           Config.Pattern_Texts.Append (Text);
                        end if;
                     end;
                  when Posix_Tools.Commands.Rg.Input.End_Of_Input =>
                     exit;
                  when Posix_Tools.Commands.Rg.Input.Read_Failed =>
                     Fail ("cannot read pattern file: " & Path);
                     exit;
                  when Posix_Tools.Commands.Rg.Input.Line_Too_Long =>
                     Fail ("pattern exceeds the 4 MiB limit in file: " & Path);
                     exit;
               end case;
            end;
         end loop;

         Posix_Tools.Commands.Rg.Input.Close (Reader, Closed);
         if not Closed and then Outcome /= Parse_Error then
            Fail ("cannot close pattern file: " & Path);
         end if;
         return Outcome /= Parse_Error;
      end Load_Pattern_File;

      procedure Set_Max_Depth (Text : String) is
         Value : Long_Long_Integer;
      begin
         if Text'Length = 0
           or else (for some Item of Text => Item not in '0' .. '9')
         then
            Fail ("invalid value for --max-depth: " & Text);
            return;
         end if;

         Value := Long_Long_Integer'Value (Text);
         if Value > Long_Long_Integer (Natural'Last) then
            Fail ("value is too large for --max-depth: " & Text);
         else
            Config.Depth_Limit := Natural (Value);
         end if;
      exception
         when Constraint_Error =>
            Fail ("value is too large for --max-depth: " & Text);
      end Set_Max_Depth;

      procedure Set_Max_Count (Text : String) is
         Value : Long_Long_Integer;
      begin
         if Text'Length = 0
           or else (for some Item of Text => Item not in '0' .. '9')
         then
            Fail ("invalid value for --max-count: " & Text);
            return;
         end if;

         Value := Long_Long_Integer'Value (Text);
         if Value > Long_Long_Integer (Natural'Last) then
            Fail ("value is too large for --max-count: " & Text);
         else
            Config.Match_Limit := Natural (Value);
         end if;
      exception
         when Constraint_Error =>
            Fail ("value is too large for --max-count: " & Text);
      end Set_Max_Count;

      procedure Set_Threads (Text : String) is
         Value : Long_Long_Integer;
      begin
         if Text'Length = 0
           or else (for some Item of Text => Item not in '0' .. '9')
         then
            Fail ("invalid value for --threads: " & Text);
            return;
         end if;

         Value := Long_Long_Integer'Value (Text);
         if Value > Long_Long_Integer (Natural'Last) then
            Fail ("value is too large for --threads: " & Text);
         else
            Config.Worker_Count := Natural (Value);
         end if;
      exception
         when Constraint_Error =>
            Fail ("value is too large for --threads: " & Text);
      end Set_Threads;

      procedure Set_Context_Count
        (Text        : String;
         Option_Name : String;
         Before      : Boolean;
         After       : Boolean;
         Specific    : Boolean)
      is
         Value : Long_Long_Integer;
      begin
         if Text'Length = 0
           or else (for some Item of Text => Item not in '0' .. '9')
         then
            Fail ("invalid value for " & Option_Name & ": " & Text);
            return;
         end if;

         Value := Long_Long_Integer'Value (Text);
         if Value > Long_Long_Integer (Natural'Last) then
            Fail ("value is too large for " & Option_Name & ": " & Text);
         else
            if Before and then (Specific or else not Before_Context_Set) then
               Config.Before_Lines := Natural (Value);
            end if;
            if After and then (Specific or else not After_Context_Set) then
               Config.After_Lines := Natural (Value);
            end if;
            Before_Context_Set := Before_Context_Set or else (Specific and then Before);
            After_Context_Set := After_Context_Set or else (Specific and then After);
         end if;
      exception
         when Constraint_Error =>
            Fail ("value is too large for " & Option_Name & ": " & Text);
      end Set_Context_Count;

      procedure Set_Max_File_Size (Text : String) is
         Last_Digit : Integer := Text'Last;
         Multiplier : Long_Long_Integer := 1;
         Value      : Long_Long_Integer;
      begin
         if Text'Length = 0 then
            Fail ("invalid value for --max-filesize: " & Text);
            return;
         end if;

         case Text (Text'Last) is
            when 'K' =>
               Multiplier := 1024;
               Last_Digit := Last_Digit - 1;
            when 'M' =>
               Multiplier := 1024 * 1024;
               Last_Digit := Last_Digit - 1;
            when 'G' =>
               Multiplier := 1024 * 1024 * 1024;
               Last_Digit := Last_Digit - 1;
            when others =>
               null;
         end case;

         if Last_Digit < Text'First
           or else (for some Index in Text'First .. Last_Digit => Text (Index) not in '0' .. '9')
         then
            Fail ("invalid value for --max-filesize: " & Text);
            return;
         end if;

         Value := Long_Long_Integer'Value (Text (Text'First .. Last_Digit));
         if Value > Long_Long_Integer'Last / Multiplier then
            Fail ("value is too large for --max-filesize: " & Text);
         else
            Config.File_Size_Limit := Value * Multiplier;
         end if;
      exception
         when Constraint_Error =>
            Fail ("value is too large for --max-filesize: " & Text);
      end Set_Max_File_Size;

      procedure Set_Sort (Text : String; Descending : Boolean) is
      begin
         if Text = "none" then
            Config.Ordering := Posix_Tools.Commands.Rg.Traversal.Unsorted;
         elsif Text = "path" then
            Config.Ordering :=
              (if Descending
               then Posix_Tools.Commands.Rg.Traversal.Path_Descending
               else Posix_Tools.Commands.Rg.Traversal.Path_Ascending);
         elsif Text = "modified" then
            Config.Ordering :=
              (if Descending
               then Posix_Tools.Commands.Rg.Traversal.Modified_Descending
               else Posix_Tools.Commands.Rg.Traversal.Modified_Ascending);
         elsif Text = "accessed" then
            Config.Ordering :=
              (if Descending
               then Posix_Tools.Commands.Rg.Traversal.Accessed_Descending
               else Posix_Tools.Commands.Rg.Traversal.Accessed_Ascending);
         elsif Text = "created" then
            Config.Ordering :=
              (if Descending
               then Posix_Tools.Commands.Rg.Traversal.Created_Descending
               else Posix_Tools.Commands.Rg.Traversal.Created_Ascending);
         else
            Fail ("invalid value for --sort: " & Text);
         end if;
      end Set_Sort;

      procedure Set_Encoding (Text : String) is
         Mode : Posix_Tools.Commands.Rg.Encodings.Encoding_Mode;
      begin
         if Posix_Tools.Commands.Rg.Encodings.Resolve_Label (Text, Mode) then
            Config.Input_Encoding := Mode;
         else
            Fail ("unknown encoding: " & Text);
         end if;
      end Set_Encoding;
   begin
      Config := (others => <>);
      Outcome := Search_Ready;

      while Index <= Context.Argument_Count loop
         declare
            Argument : constant String := Context.Argument (Index);
         begin
            if not Options_Ended and then Argument = "--" then
               Options_Ended := True;
            elsif not Options_Ended and then Argument = "--help" then
               Outcome := Show_Help;
               return;
            elsif not Options_Ended and then Argument = "--version" then
               Outcome := Show_Version;
               return;
            elsif not Options_Ended and then Argument = "--fixed-strings" then
               Config.Fixed := True;
            elsif not Options_Ended and then Argument = "--files" then
               Config.List_Files := True;
               Config.List_Types := False;
            elsif not Options_Ended and then Argument = "--stats" then
               Config.Show_Statistics := True;
            elsif not Options_Ended and then Argument = "--no-stats" then
               Config.Show_Statistics := False;
            elsif not Options_Ended and then Argument = "--json" then
               Config.Json := True;
            elsif not Options_Ended and then Argument = "--no-json" then
               Config.Json := False;
            elsif not Options_Ended
              and then (Argument = "--threads" or else Argument = "-j")
            then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: " & Argument);
                  return;
               end if;
               Index := Index + 1;
               Set_Threads (Context.Argument (Index));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length >= 10
              and then Argument (Argument'First .. Argument'First + 9) = "--threads="
            then
               Set_Threads (Argument (Argument'First + 10 .. Argument'Last));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--debug" then
               Config.Logging := Posix_Tools.Commands.Rg.Diagnostics.Debug_Logging;
            elsif not Options_Ended and then Argument = "--trace" then
               Config.Logging := Posix_Tools.Commands.Rg.Diagnostics.Trace_Logging;
            elsif not Options_Ended
              and then (Argument = "--encoding" or else Argument = "-E")
            then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: " & Argument);
                  return;
               end if;
               Index := Index + 1;
               Set_Encoding (Context.Argument (Index));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--no-encoding" then
               Config.Input_Encoding := Posix_Tools.Commands.Rg.Input.Automatic_Encoding;
            elsif not Options_Ended and then Argument'Length >= 11
              and then Argument (Argument'First .. Argument'First + 10) = "--encoding="
            then
               Set_Encoding (Argument (Argument'First + 11 .. Argument'Last));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length > 2
              and then Argument (Argument'First .. Argument'First + 1) = "-E"
            then
               Set_Encoding (Argument (Argument'First + 2 .. Argument'Last));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--color" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --color");
                  return;
               end if;
               Index := Index + 1;
               Set_Color (Context.Argument (Index));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length >= 8
              and then Argument (Argument'First .. Argument'First + 7) = "--color="
            then
               Set_Color (Argument (Argument'First + 8 .. Argument'Last));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--colors" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --colors");
                  return;
               end if;
               Index := Index + 1;
               Add_Color_Rule (Context.Argument (Index));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length >= 9
              and then Argument (Argument'First .. Argument'First + 8) = "--colors="
            then
               Add_Color_Rule (Argument (Argument'First + 9 .. Argument'Last));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended
              and then (Argument = "--sort" or else Argument = "--sortr")
            then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: " & Argument);
                  return;
               end if;
               Index := Index + 1;
               Set_Sort
                 (Context.Argument (Index), Descending => Argument = "--sortr");
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length >= 7
              and then Argument (Argument'First .. Argument'First + 6) = "--sort="
            then
               Set_Sort
                 (Argument (Argument'First + 7 .. Argument'Last), Descending => False);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length >= 8
              and then Argument (Argument'First .. Argument'First + 7) = "--sortr="
            then
               Set_Sort
                 (Argument (Argument'First + 8 .. Argument'Last), Descending => True);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--type-list" then
               Config.List_Types := True;
               Config.List_Files := False;
            elsif not Options_Ended and then Argument = "--type" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --type");
                  return;
               end if;
               Index := Index + 1;
               Take_Type (Context.Argument (Index), Include => True);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length >= 7
              and then Argument (Argument'First .. Argument'First + 6) = "--type="
            then
               Take_Type (Argument (Argument'First + 7 .. Argument'Last), Include => True);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--type-not" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --type-not");
                  return;
               end if;
               Index := Index + 1;
               Take_Type (Context.Argument (Index), Include => False);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length >= 11
              and then Argument (Argument'First .. Argument'First + 10) = "--type-not="
            then
               Take_Type (Argument (Argument'First + 11 .. Argument'Last), Include => False);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--file" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --file");
                  return;
               end if;
               Index := Index + 1;
               Take_Pattern_File (Context.Argument (Index));
            elsif not Options_Ended and then Argument'Length >= 7
              and then Argument (Argument'First .. Argument'First + 6) = "--file="
            then
               Take_Pattern_File (Argument (Argument'First + 7 .. Argument'Last));
            elsif not Options_Ended and then Argument = "--glob" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --glob");
                  return;
               end if;
               Index := Index + 1;
               Config.Glob_Texts.Append (Context.Argument (Index));
            elsif not Options_Ended and then Argument'Length >= 7
              and then Argument (Argument'First .. Argument'First + 6) = "--glob="
            then
               Config.Glob_Texts.Append (Argument (Argument'First + 7 .. Argument'Last));
            elsif not Options_Ended and then Argument = "--ignore-case" then
               Config.Case_Mode := Insensitive_Case;
            elsif not Options_Ended and then Argument = "--case-sensitive" then
               Config.Case_Mode := Sensitive_Case;
            elsif not Options_Ended and then Argument = "--smart-case" then
               Config.Case_Mode := Smart_Case;
            elsif not Options_Ended and then Argument = "--word-regexp" then
               Config.Word := True;
            elsif not Options_Ended and then Argument = "--line-regexp" then
               Config.Line := True;
            elsif not Options_Ended and then Argument = "--hidden" then
               Config.Hidden := True;
            elsif not Options_Ended and then Argument = "--follow" then
               Config.Follow := True;
            elsif not Options_Ended and then Argument = "--no-follow" then
               Config.Follow := False;
            elsif not Options_Ended and then Argument = "--one-file-system" then
               Config.Single_Device := True;
            elsif not Options_Ended and then Argument = "--no-one-file-system" then
               Config.Single_Device := False;
            elsif not Options_Ended and then Argument = "--text" then
               Config.Binary_Mode := Posix_Tools.Commands.Rg.Search.Treat_As_Text;
            elsif not Options_Ended and then Argument = "--no-text" then
               Config.Binary_Mode := Posix_Tools.Commands.Rg.Search.Detect_Binary;
            elsif not Options_Ended and then Argument = "--binary" then
               Config.Binary_Mode := Posix_Tools.Commands.Rg.Search.Search_Binary;
            elsif not Options_Ended and then Argument = "--no-binary" then
               Config.Binary_Mode := Posix_Tools.Commands.Rg.Search.Detect_Binary;
            elsif not Options_Ended and then Argument = "--null" then
               Config.Nul_Paths := True;
            elsif not Options_Ended and then Argument = "--no-null" then
               Config.Nul_Paths := False;
            elsif not Options_Ended and then Argument = "--null-data" then
               Config.Nul_Records := True;
            elsif not Options_Ended and then Argument = "--no-null-data" then
               Config.Nul_Records := False;
            elsif not Options_Ended and then Argument = "--multiline" then
               Config.Multi_Record := True;
            elsif not Options_Ended and then Argument = "--no-multiline" then
               Config.Multi_Record := False;
            elsif not Options_Ended and then Argument = "--multiline-dotall" then
               Config.Dotall := True;
            elsif not Options_Ended and then Argument = "--no-multiline-dotall" then
               Config.Dotall := False;
            elsif not Options_Ended and then Argument = "--replace" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --replace");
                  return;
               end if;
               Index := Index + 1;
               Config.Replace_Set := True;
               Config.Replace_Text := To_Unbounded_String (Context.Argument (Index));
            elsif not Options_Ended and then Argument'Length >= 10
              and then Argument (Argument'First .. Argument'First + 9) = "--replace="
            then
               Config.Replace_Set := True;
               Config.Replace_Text :=
                 To_Unbounded_String (Argument (Argument'First + 10 .. Argument'Last));
            elsif not Options_Ended and then Argument = "--no-ignore" then
               Config.Ignore_Files := False;
            elsif not Options_Ended and then Argument = "--no-ignore-vcs" then
               Config.Vcs_Ignore := False;
            elsif not Options_Ended and then Argument = "--no-ignore-parent" then
               Config.Parent_Ignore := False;
            elsif not Options_Ended and then Argument = "--max-depth" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --max-depth");
                  return;
               end if;
               Index := Index + 1;
               Set_Max_Depth (Context.Argument (Index));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length > 12
              and then Argument (Argument'First .. Argument'First + 11) = "--max-depth="
            then
               Set_Max_Depth (Argument (Argument'First + 12 .. Argument'Last));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--max-filesize" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --max-filesize");
                  return;
               end if;
               Index := Index + 1;
               Set_Max_File_Size (Context.Argument (Index));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--max-filesize=" then
               Set_Max_File_Size ("");
               return;
            elsif not Options_Ended and then Argument'Length > 15
              and then Argument (Argument'First .. Argument'First + 14) = "--max-filesize="
            then
               Set_Max_File_Size (Argument (Argument'First + 15 .. Argument'Last));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--line-number" then
               Config.Line_Numbers := Enabled;
            elsif not Options_Ended and then Argument = "--no-line-number" then
               Config.Line_Numbers := Disabled;
            elsif not Options_Ended and then Argument = "--with-filename" then
               Config.File_Names := Enabled;
            elsif not Options_Ended and then Argument = "--no-filename" then
               Config.File_Names := Disabled;
            elsif not Options_Ended and then Argument = "--column" then
               Config.Column_Number := True;
            elsif not Options_Ended and then Argument = "--no-column" then
               Config.Column_Number := False;
            elsif not Options_Ended and then Argument = "--heading" then
               Config.Heading_Mode := Enabled;
            elsif not Options_Ended and then Argument = "--no-heading" then
               Config.Heading_Mode := Disabled;
            elsif not Options_Ended and then Argument = "--invert-match" then
               Config.Inverted := True;
            elsif not Options_Ended and then Argument = "--quiet" then
               Config.Result_Format := Posix_Tools.Commands.Rg.Rendering.Quiet;
            elsif not Options_Ended and then Argument = "--count" then
               if Config.Result_Format /= Posix_Tools.Commands.Rg.Rendering.Quiet then
                  Config.Result_Format := Posix_Tools.Commands.Rg.Rendering.Count_Lines;
               end if;
            elsif not Options_Ended and then Argument = "--count-matches" then
               if Config.Result_Format /= Posix_Tools.Commands.Rg.Rendering.Quiet then
                  Config.Result_Format := Posix_Tools.Commands.Rg.Rendering.Count_Matches;
               end if;
            elsif not Options_Ended and then Argument = "--only-matching" then
               Config.Match_Only := True;
            elsif not Options_Ended and then Argument = "--files-with-matches" then
               if Config.Result_Format /= Posix_Tools.Commands.Rg.Rendering.Quiet then
                  Config.Result_Format := Posix_Tools.Commands.Rg.Rendering.Files_With_Matches;
               end if;
            elsif not Options_Ended and then Argument = "--files-without-match" then
               if Config.Result_Format /= Posix_Tools.Commands.Rg.Rendering.Quiet then
                  Config.Result_Format := Posix_Tools.Commands.Rg.Rendering.Files_Without_Match;
               end if;
            elsif not Options_Ended and then Argument = "--max-count" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --max-count");
                  return;
               end if;
               Index := Index + 1;
               Set_Max_Count (Context.Argument (Index));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--after-context" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --after-context");
                  return;
               end if;
               Index := Index + 1;
               Set_Context_Count
                 (Context.Argument (Index),
                  "--after-context",
                  Before   => False,
                  After    => True,
                  Specific => True);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length >= 16
              and then Argument (Argument'First .. Argument'First + 15) = "--after-context="
            then
               Set_Context_Count
                 (Argument (Argument'First + 16 .. Argument'Last),
                  "--after-context",
                  Before => False,
                  After  => True,
                  Specific => True);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--before-context" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --before-context");
                  return;
               end if;
               Index := Index + 1;
               Set_Context_Count
                 (Context.Argument (Index),
                  "--before-context",
                  Before   => True,
                  After    => False,
                  Specific => True);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length >= 17
              and then Argument (Argument'First .. Argument'First + 16) = "--before-context="
            then
               Set_Context_Count
                 (Argument (Argument'First + 17 .. Argument'Last),
                  "--before-context",
                  Before => True,
                  After  => False,
                  Specific => True);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--context" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --context");
                  return;
               end if;
               Index := Index + 1;
               Set_Context_Count
                 (Context.Argument (Index),
                  "--context",
                  Before   => True,
                  After    => True,
                  Specific => False);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length >= 10
              and then Argument (Argument'First .. Argument'First + 9) = "--context="
            then
               Set_Context_Count
                 (Argument (Argument'First + 10 .. Argument'Last),
                  "--context",
                  Before => True,
                  After  => True,
                  Specific => False);
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument = "--context-separator" then
               if Index = Context.Argument_Count then
                  Fail ("option requires an argument: --context-separator");
                  return;
               end if;
               Index := Index + 1;
               Config.Separator := To_Unbounded_String (Context.Argument (Index));
            elsif not Options_Ended and then Argument'Length >= 20
              and then Argument (Argument'First .. Argument'First + 19) = "--context-separator="
            then
               Config.Separator :=
                 To_Unbounded_String (Argument (Argument'First + 20 .. Argument'Last));
            elsif not Options_Ended and then Argument'Length > 12
              and then Argument (Argument'First .. Argument'First + 11) = "--max-count="
            then
               Set_Max_Count (Argument (Argument'First + 12 .. Argument'Last));
               if Outcome = Parse_Error then
                  return;
               end if;
            elsif not Options_Ended and then Argument'Length > 2
              and then Argument (Argument'First .. Argument'First + 1) = "--"
            then
               Fail ("unknown option: " & Argument);
               return;
            elsif not Options_Ended and then Argument'Length > 1
              and then Argument (Argument'First) = '-'
            then
               declare
                  Position : Positive := Argument'First + 1;
               begin
                  while Position <= Argument'Last loop
                     case Argument (Position) is
                        when 'F' =>
                           Config.Fixed := True;
                        when 'i' =>
                           Config.Case_Mode := Insensitive_Case;
                        when 's' =>
                           Config.Case_Mode := Sensitive_Case;
                        when 'S' =>
                           Config.Case_Mode := Smart_Case;
                        when 'w' =>
                           Config.Word := True;
                        when 'x' =>
                           Config.Line := True;
                        when 'n' =>
                           Config.Line_Numbers := Enabled;
                        when 'N' =>
                           Config.Line_Numbers := Disabled;
                        when 'H' =>
                           Config.File_Names := Enabled;
                        when 'I' =>
                           Config.File_Names := Disabled;
                        when 'L' =>
                           Config.Follow := True;
                        when 'U' =>
                           Config.Multi_Record := True;
                        when 'v' =>
                           Config.Inverted := True;
                        when 'a' =>
                           Config.Binary_Mode := Posix_Tools.Commands.Rg.Search.Treat_As_Text;
                        when '0' =>
                           Config.Nul_Paths := True;
                        when 'u' =>
                           if Config.Unrestricted < 3 then
                              Config.Unrestricted := Config.Unrestricted + 1;
                              case Config.Unrestricted is
                                 when 1 =>
                                    Config.Ignore_Files := False;
                                 when 2 =>
                                    Config.Hidden := True;
                                 when 3 =>
                                    Config.Binary_Mode :=
                                      Posix_Tools.Commands.Rg.Search.Search_Binary;
                                 when others =>
                                    null;
                              end case;
                           end if;
                        when 'q' =>
                           Config.Result_Format := Posix_Tools.Commands.Rg.Rendering.Quiet;
                        when 'c' =>
                           if Config.Result_Format /= Posix_Tools.Commands.Rg.Rendering.Quiet then
                              Config.Result_Format := Posix_Tools.Commands.Rg.Rendering.Count_Lines;
                           end if;
                        when 'l' =>
                           if Config.Result_Format /= Posix_Tools.Commands.Rg.Rendering.Quiet then
                              Config.Result_Format := Posix_Tools.Commands.Rg.Rendering.Files_With_Matches;
                           end if;
                        when 'o' =>
                           Config.Match_Only := True;
                        when 'r' =>
                           if Position < Argument'Last then
                              Config.Replace_Text :=
                                To_Unbounded_String (Argument (Position + 1 .. Argument'Last));
                           elsif Index < Context.Argument_Count then
                              Index := Index + 1;
                              Config.Replace_Text := To_Unbounded_String (Context.Argument (Index));
                           else
                              Fail ("option requires an argument: -r");
                              return;
                           end if;
                           Config.Replace_Set := True;
                           exit;
                        when 'j' =>
                           if Position < Argument'Last then
                              Set_Threads (Argument (Position + 1 .. Argument'Last));
                           elsif Index < Context.Argument_Count then
                              Index := Index + 1;
                              Set_Threads (Context.Argument (Index));
                           else
                              Fail ("option requires an argument: -j");
                           end if;
                           if Outcome = Parse_Error then
                              return;
                           end if;
                           exit;
                        when 'g' =>
                           if Position < Argument'Last then
                              Config.Glob_Texts.Append (Argument (Position + 1 .. Argument'Last));
                           elsif Index < Context.Argument_Count then
                              Index := Index + 1;
                              Config.Glob_Texts.Append (Context.Argument (Index));
                           else
                              Fail ("option requires an argument: -g");
                              return;
                           end if;
                           exit;
                        when 't' | 'T' =>
                           declare
                              Include : constant Boolean := Argument (Position) = 't';
                           begin
                              if Position < Argument'Last then
                                 Take_Type
                                   (Argument (Position + 1 .. Argument'Last), Include);
                              elsif Index < Context.Argument_Count then
                                 Index := Index + 1;
                                 Take_Type (Context.Argument (Index), Include);
                              else
                                 Fail
                                   ("option requires an argument: -" & Argument (Position));
                              end if;
                           end;
                           if Outcome = Parse_Error then
                              return;
                           end if;
                           exit;
                        when 'm' =>
                           if Position < Argument'Last then
                              Set_Max_Count (Argument (Position + 1 .. Argument'Last));
                           elsif Index < Context.Argument_Count then
                              Index := Index + 1;
                              Set_Max_Count (Context.Argument (Index));
                           else
                              Fail ("option requires an argument: -m");
                           end if;
                           if Outcome = Parse_Error then
                              return;
                           end if;
                           exit;
                        when 'A' | 'B' | 'C' =>
                           declare
                              Option : constant Character := Argument (Position);
                              Value  : Unbounded_String;
                           begin
                              if Position < Argument'Last then
                                 Value := To_Unbounded_String
                                   (Argument (Position + 1 .. Argument'Last));
                              elsif Index < Context.Argument_Count then
                                 Index := Index + 1;
                                 Value := To_Unbounded_String (Context.Argument (Index));
                              else
                                 Fail ("option requires an argument: -" & Option);
                                 return;
                              end if;
                              Set_Context_Count
                                (To_String (Value),
                                 "-" & Option,
                                 Before => Option in 'B' | 'C',
                                 After  => Option in 'A' | 'C',
                                 Specific => Option /= 'C');
                           end;
                           if Outcome = Parse_Error then
                              return;
                           end if;
                           exit;
                        when 'e' =>
                           if Position < Argument'Last then
                              Take_Pattern (Argument (Position + 1 .. Argument'Last));
                           elsif Index < Context.Argument_Count then
                              Index := Index + 1;
                              Take_Pattern (Context.Argument (Index));
                           else
                              Fail ("option requires an argument: -e");
                              return;
                           end if;
                           exit;
                        when 'f' =>
                           if Position < Argument'Last then
                              Take_Pattern_File (Argument (Position + 1 .. Argument'Last));
                           elsif Index < Context.Argument_Count then
                              Index := Index + 1;
                              Take_Pattern_File (Context.Argument (Index));
                           else
                              Fail ("option requires an argument: -f");
                              return;
                           end if;
                           exit;
                        when others =>
                           Fail ("unknown option: -" & Argument (Position));
                           return;
                     end case;
                     Position := Position + 1;
                  end loop;
               end;
            else
               Operands.Append (Argument);
            end if;
         end;
         Index := Index + 1;
      end loop;

      if Config.List_Types then
         null;
      elsif Config.List_Files then
         if Config.Fixed
           or else Config.Word
           or else Config.Line
           or else Config.Line_Numbers /= Automatic
           or else Config.File_Names /= Automatic
           or else Config.Column_Number
           or else Config.Inverted
           or else Config.Match_Limit /= Natural'Last
           or else Config.Before_Lines /= 0
           or else Config.After_Lines /= 0
           or else Config.Result_Format /= Posix_Tools.Commands.Rg.Rendering.Matching_Lines
           or else Config.Match_Only
           or else Config.Replace_Set
         then
            Fail ("--files cannot be combined with search or result options");
            return;
         end if;
         Config.Paths := Operands;
      elsif Has_Explicit_Pattern then
         Config.Paths := Operands;
      elsif Operands.Is_Empty then
         Fail ("a pattern is required");
         return;
      else
         Take_Pattern (Operands.First_Element);
         for Position in Operands.First_Index + 1 .. Operands.Last_Index loop
            Config.Paths.Append (Operands.Element (Position));
         end loop;
      end if;

      if not Config.List_Files and then not Config.List_Types then
         for Source of Config.Pattern_Sources loop
            if Source (Source'First) = File_Pattern
              and then Source (Source'First + 1 .. Source'Last) = "-"
            then
               Config.Used_Pattern_Stdin := True;
            end if;
         end loop;

         if Config.Used_Pattern_Stdin then
            for Search_Path of Config.Paths loop
               if Search_Path = "-" then
                  Fail ("standard input cannot be used for both patterns and search data");
                  return;
               end if;
            end loop;
         end if;

         for Source of Config.Pattern_Sources loop
            declare
               Payload : constant String := Source (Source'First + 1 .. Source'Last);
            begin
               if Source (Source'First) = Inline_Pattern then
                  Config.Pattern_Texts.Append (Payload);
               elsif not Load_Pattern_File (Payload) then
                  return;
               end if;
            end;
         end loop;
      end if;
   end Parse;

   function Case_Handling
     (Config : Invocation) return Posix_Tools.Commands.Rg.Patterns.Case_Mode
   is
   begin
      case Config.Case_Mode is
         when Sensitive_Case =>
            return Posix_Tools.Commands.Rg.Patterns.Sensitive;
         when Insensitive_Case =>
            return Posix_Tools.Commands.Rg.Patterns.Insensitive;
         when Smart_Case =>
            for Source of Config.Pattern_Texts loop
               if Regexp.Contains_Uppercase (Source, Regexp.UTF_8_Mode) then
                  return Posix_Tools.Commands.Rg.Patterns.Sensitive;
               end if;
            end loop;
            return Posix_Tools.Commands.Rg.Patterns.Insensitive;
      end case;
   end Case_Handling;

   function Diagnostic (Config : Invocation) return String is
   begin
      return (if Config.Error_Text.Is_Empty then "" else Config.Error_Text.First_Element);
   end Diagnostic;

   function Columns (Config : Invocation) return Boolean is
   begin
      return Config.Column_Number;
   end Columns;

   function Binary_Handling
     (Config : Invocation) return Posix_Tools.Commands.Rg.Search.Binary_Policy is
   begin
      return Config.Binary_Mode;
   end Binary_Handling;

   function After_Context (Config : Invocation) return Natural is
   begin
      return Config.After_Lines;
   end After_Context;

   function Before_Context (Config : Invocation) return Natural is
   begin
      return Config.Before_Lines;
   end Before_Context;

   function Context_Separator (Config : Invocation) return String is
   begin
      return To_String (Config.Separator);
   end Context_Separator;

   function Fixed_Strings (Config : Invocation) return Boolean is
   begin
      return Config.Fixed;
   end Fixed_Strings;

   function Files_Only (Config : Invocation) return Boolean is
   begin
      return Config.List_Files;
   end Files_Only;

   function Type_Filter
     (Config : Invocation) return Posix_Tools.Commands.Rg.Types.Policy is
   begin
      return Config.File_Types;
   end Type_Filter;

   function Type_List_Only (Config : Invocation) return Boolean is
   begin
      return Config.List_Types;
   end Type_List_Only;

   function Include_Hidden (Config : Invocation) return Boolean is
   begin
      return Config.Hidden;
   end Include_Hidden;

   function Headings
     (Config             : Invocation;
      Output_Is_Terminal : Boolean) return Boolean
   is
   begin
      return
        Config.Heading_Mode = Enabled
        or else (Config.Heading_Mode = Automatic and then Output_Is_Terminal);
   end Headings;

   function Glob (Config : Invocation; Index : Positive) return String is
   begin
      return Config.Glob_Texts.Element (Index);
   end Glob;

   function Glob_Count (Config : Invocation) return Natural is
   begin
      return Natural (Config.Glob_Texts.Length);
   end Glob_Count;

   function Follow_Links (Config : Invocation) return Boolean is
   begin
      return Config.Follow;
   end Follow_Links;

   function Invert_Match (Config : Invocation) return Boolean is
   begin
      return Config.Inverted;
   end Invert_Match;

   function Max_Depth (Config : Invocation) return Natural is
   begin
      return Config.Depth_Limit;
   end Max_Depth;

   function Max_File_Size (Config : Invocation) return Long_Long_Integer is
   begin
      return Config.File_Size_Limit;
   end Max_File_Size;

   function Sort_Order
     (Config : Invocation) return Posix_Tools.Commands.Rg.Traversal.Sort_Order is
   begin
      return Config.Ordering;
   end Sort_Order;

   function Threads (Config : Invocation) return Natural is
   begin
      return Config.Worker_Count;
   end Threads;

   function One_File_System (Config : Invocation) return Boolean is
   begin
      return Config.Single_Device;
   end One_File_System;

   function Null_Data (Config : Invocation) return Boolean is
   begin
      return Config.Nul_Records;
   end Null_Data;

   function Null_Pathnames (Config : Invocation) return Boolean is
   begin
      return Config.Nul_Paths;
   end Null_Pathnames;

   function Multiline (Config : Invocation) return Boolean is
   begin
      return Config.Multi_Record;
   end Multiline;

   function Multiline_Dotall (Config : Invocation) return Boolean is
   begin
      return Config.Dotall;
   end Multiline_Dotall;

   function Has_Replacement (Config : Invocation) return Boolean is
   begin
      return Config.Replace_Set;
   end Has_Replacement;

   function Replacement (Config : Invocation) return String is
   begin
      return To_String (Config.Replace_Text);
   end Replacement;

   function Statistics (Config : Invocation) return Boolean is
   begin
      return Config.Show_Statistics;
   end Statistics;

   function Json_Output (Config : Invocation) return Boolean is
   begin
      return Config.Json;
   end Json_Output;

   function Diagnostics
     (Config : Invocation) return Posix_Tools.Commands.Rg.Diagnostics.Log_Level is
   begin
      return Config.Logging;
   end Diagnostics;

   function Encoding
     (Config : Invocation) return Posix_Tools.Commands.Rg.Input.Encoding_Mode is
   begin
      return Config.Input_Encoding;
   end Encoding;

   function Color_Handling
     (Config : Invocation) return Posix_Tools.Commands.Rg.Rendering.Color_Mode is
   begin
      return Config.Color_Output;
   end Color_Handling;

   function Color_Palette
     (Config : Invocation) return Posix_Tools.Commands.Rg.Colors.Palette is
   begin
      return Config.Colors;
   end Color_Palette;

   function Max_Count (Config : Invocation) return Natural is
   begin
      return Config.Match_Limit;
   end Max_Count;

   function Mode
     (Config : Invocation) return Posix_Tools.Commands.Rg.Rendering.Result_Mode
   is
   begin
      if Config.Inverted then
         return
           (if Config.Result_Format = Posix_Tools.Commands.Rg.Rendering.Count_Matches
            then Posix_Tools.Commands.Rg.Rendering.Count_Lines
            else Config.Result_Format);
      elsif Config.Match_Only
        and then Config.Result_Format = Posix_Tools.Commands.Rg.Rendering.Matching_Lines
      then
         return Posix_Tools.Commands.Rg.Rendering.Only_Matching;
      elsif Config.Match_Only
        and then Config.Result_Format = Posix_Tools.Commands.Rg.Rendering.Count_Lines
      then
         return Posix_Tools.Commands.Rg.Rendering.Count_Matches;
      else
         return Config.Result_Format;
      end if;
   end Mode;

   function Only_Matching (Config : Invocation) return Boolean is
   begin
      return Config.Match_Only;
   end Only_Matching;

   function Line_Numbers
     (Config             : Invocation;
      Output_Is_Terminal : Boolean) return Boolean
   is
   begin
      return
        Config.Line_Numbers = Enabled
        or else
          (Config.Line_Numbers = Automatic
           and then (Config.Column_Number or else Output_Is_Terminal));
   end Line_Numbers;

   function Path (Config : Invocation; Index : Positive) return String is
   begin
      return Config.Paths.Element (Index);
   end Path;

   function Path_Count (Config : Invocation) return Natural is
   begin
      return Natural (Config.Paths.Length);
   end Path_Count;

   function Pattern (Config : Invocation; Index : Positive) return String is
   begin
      return Config.Pattern_Texts.Element (Index);
   end Pattern;

   function Pattern_Count (Config : Invocation) return Natural is
   begin
      return Natural (Config.Pattern_Texts.Length);
   end Pattern_Count;

   function Pattern_Stdin_Used (Config : Invocation) return Boolean is
   begin
      return Config.Used_Pattern_Stdin;
   end Pattern_Stdin_Used;

   function Prefix_Filename
     (Config          : Invocation;
      Automatic_Value : Boolean) return Boolean
   is
   begin
      return
        Config.File_Names = Enabled
        or else (Config.File_Names = Automatic and then Automatic_Value);
   end Prefix_Filename;

   function Use_Ignore_Files (Config : Invocation) return Boolean is
   begin
      return Config.Ignore_Files;
   end Use_Ignore_Files;

   function Use_Parent_Ignore (Config : Invocation) return Boolean is
   begin
      return Config.Parent_Ignore;
   end Use_Parent_Ignore;

   function Use_Vcs_Ignore (Config : Invocation) return Boolean is
   begin
      return Config.Vcs_Ignore;
   end Use_Vcs_Ignore;

   function Whole_Line (Config : Invocation) return Boolean is
   begin
      return Config.Line;
   end Whole_Line;

   function Whole_Word (Config : Invocation) return Boolean is
   begin
      return Config.Word;
   end Whole_Word;
end Posix_Tools.Commands.Rg.Options;
