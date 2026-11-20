with Ada.Containers.Vectors;
with Ada.Real_Time;
with Posix_Tools.Commands.Rg.Json;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Rg_Arithmetic;

package body Posix_Tools.Commands.Rg.Search is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Commands.Rg.Input.Read_Outcome;
   use type Posix_Tools.Commands.Rg.Rendering.Result_Mode;
   use type Posix_Tools.Commands.Rg.Patterns.Replacement_Status;
   use type Regexp.Match_Status;
   use type Regexp.Match_Abort_Callback;
   use type Ada.Real_Time.Time;

   procedure Search_Source
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Name        : String;
      Label       : String;
      Options     : Execution_Options;
      Patterns    : Posix_Tools.Commands.Rg.Patterns.Compiled_Pattern_Array;
      Outcome     : out Search_Outcome)
   is
      Reader : Posix_Tools.Commands.Rg.Input.Reader;
      Opened : Boolean := False;
      Closed : Boolean;
      Number : Natural := 0;
      Selected_Count : Natural := 0;
      Match_Total : Natural := 0;
      Byte_Offset : Natural := 0;
      First_Nul_Offset : Natural := Posix_Tools.Commands.Rg.Input.No_Nul_Byte;
      Saw_Nul : Boolean := False;
      After_Remaining : Natural := 0;
      Last_Output_Number : Natural := 0;
      Have_Output_Group : Boolean := False;
      Context_Bytes : Natural := 0;
      Context_Buffer_Failed : Boolean := False;
      Heading_Written : Boolean := False;
      Started : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;

      Maximum_Context_Bytes : constant Natural := 64 * 1024 * 1024;
      Maximum_Multiline_Bytes : constant Natural := 64 * 1024 * 1024;
      Maximum_Replacement_Bytes : constant Natural := 64 * 1024 * 1024;
      Context_Active : constant Boolean :=
        Options.Mode in
          Posix_Tools.Commands.Rg.Rendering.Matching_Lines
          | Posix_Tools.Commands.Rg.Rendering.Only_Matching
        and then (Options.Before_Context > 0 or else Options.After_Context > 0);

      type Buffered_Line is record
         Number : Positive;
         Text   : Unbounded_String;
         Offset : Natural;
         Terminated : Boolean := False;
      end record;

      package Line_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Positive,
         Element_Type => Buffered_Line);

      Before_Lines : Line_Vectors.Vector;

      type Multiline_Line is record
         Number      : Positive;
         Text        : Unbounded_String;
         First       : Positive;
         Terminated  : Boolean := False;
         Matched     : Boolean := False;
         Starts_Match : Boolean := False;
         Selected    : Boolean := False;
         Show        : Boolean := False;
         Column      : Positive := 1;
         Column_Set  : Boolean := False;
      end record;

      package Multiline_Line_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Positive,
         Element_Type => Multiline_Line);

      type Match_Span is record
         First        : Positive;
         Last         : Natural;
         Start_Line   : Positive;
         End_Line     : Positive;
         Start_Column : Positive;
         Output_Line  : Positive;
         Replacement  : Unbounded_String;
      end record;

      package Match_Span_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Positive,
         Element_Type => Match_Span);

      function Added (Left, Right : Natural) return Natural renames
        Posix_Tools.Rg_Arithmetic.Saturating_Add;

      procedure Record_Output (Count : Natural);

      procedure Record_Output (Count : Natural) is
      begin
         if Options.Collect_Statistics then
            Outcome.Bytes_Printed := Added (Outcome.Bytes_Printed, Count);
         end if;
      end Record_Output;

      function Result_Style return Posix_Tools.Commands.Rg.Rendering.Format;

      procedure Put_Binary_Match;
      procedure Begin_Output;
      procedure Buffer_Context_Line
        (Line : Unbounded_String; Offset : Natural; Terminated : Boolean);
      procedure Begin_Selected_Group;
      procedure Put_Context_Line
        (Line : Unbounded_String; Line_Number : Positive; Offset : Natural; Terminated : Boolean);
      procedure Search_Multiline;

      procedure Put_Binary_Match is
         Prefix : constant String :=
           (if not Options.Style.Prefix_Name
            then ""
            elsif Options.Style.Null_Pathnames
            then Label & String'(1 => ASCII.NUL)
            else Label & ": ");
      begin
         declare
            Output : constant String :=
              Prefix & "binary file matches (found ""\0"" byte around offset"
              & Natural'Image (First_Nul_Offset) & ")";
         begin
            Context.Put_Line (Output);
            Record_Output (Output'Length + 1);
         end;
      end Put_Binary_Match;

      function Result_Style return Posix_Tools.Commands.Rg.Rendering.Format is
         Result : Posix_Tools.Commands.Rg.Rendering.Format := Options.Style;
      begin
         if Result.Heading then
            Result.Prefix_Name := False;
         end if;
         return Result;
      end Result_Style;

      procedure Begin_Output is
      begin
         if Heading_Written then
            return;
         end if;

         if Options.Style.Heading then
            if Options.Separate_First_Group then
               Context.Put (String'(1 => Options.Style.Record_Terminator));
               Record_Output (1);
            end if;
            if Options.Style.Prefix_Name then
               Posix_Tools.Commands.Rg.Rendering.Put_Heading
                 (Context, Label, Options.Style, Record_Output'Access);
            end if;
         end if;
         if Options.Json_Output then
            declare
               Output : constant String :=
                 Posix_Tools.Commands.Rg.Json.Begin_Event (Label) & ASCII.LF;
            begin
               Context.Put (Output);
               Record_Output (Output'Length);
            end;
         end if;
         Heading_Written := True;
      end Begin_Output;

      procedure Put_Context_Line
        (Line : Unbounded_String; Line_Number : Positive; Offset : Natural; Terminated : Boolean) is
      begin
         Begin_Output;
         if Options.Json_Output then
            declare
               Output : constant String :=
                 Posix_Tools.Commands.Rg.Json.Line_Event
                   ("context",
                    Label,
                    To_String (Line),
                    Terminated,
                    Line_Number,
                    Offset,
                    "",
                    (if Options.Null_Data then ASCII.NUL else ASCII.LF))
                 & ASCII.LF;
            begin
               Context.Put (Output);
               Record_Output (Output'Length);
            end;
         else
            Posix_Tools.Commands.Rg.Rendering.Put_Context_Line
              (Context, Label, Line, Line_Number, Result_Style, Record_Output'Access);
         end if;
         Outcome.Had_Result := True;
         Have_Output_Group := True;
         Last_Output_Number := Line_Number;
      end Put_Context_Line;

      procedure Buffer_Context_Line
        (Line : Unbounded_String; Offset : Natural; Terminated : Boolean) is
         Size : constant Natural := Length (Line);
      begin
         if not Context_Active or else Options.Before_Context = 0 then
            return;
         end if;

         while Natural (Before_Lines.Length) >= Options.Before_Context loop
            Context_Bytes := Context_Bytes - Length (Before_Lines.First_Element.Text);
            Before_Lines.Delete_First;
         end loop;

         if Size > Maximum_Context_Bytes - Context_Bytes then
            Posix_Tools.Commands.Rg.Diagnostics.Error_Line
              (Context, "leading context exceeds the 64 MiB buffer limit in "
               & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
            Outcome.Input_Error := True;
            Context_Buffer_Failed := True;
            return;
         end if;

         Before_Lines.Append
           (Buffered_Line'(Number => Number, Text => Line, Offset => Offset, Terminated => Terminated));
         Context_Bytes := Context_Bytes + Size;
      end Buffer_Context_Line;

      procedure Begin_Selected_Group is
         First_Number : constant Positive :=
           (if Number > Options.Before_Context
            then Number - Options.Before_Context
            else 1);
         Needs_Separator : constant Boolean :=
           (if Have_Output_Group
            then First_Number > Added (Last_Output_Number, 1)
            else Options.Separate_First_Group);
      begin
         Begin_Output;
         if Needs_Separator and then not Options.Json_Output then
            if not Options.Style.Heading or else Have_Output_Group then
               Posix_Tools.Commands.Rg.Rendering.Put_Context_Separator
                 (Context,
                  To_String (Options.Context_Separator),
                  Options.Style.Record_Terminator,
                  Record_Output'Access,
                  Options.Style);
            end if;
         end if;

         for Item of Before_Lines loop
            if Item.Number >= First_Number and then Item.Number > Last_Output_Number then
               Put_Context_Line (Item.Text, Item.Number, Item.Offset, Item.Terminated);
            end if;
         end loop;
         Before_Lines.Clear;
         Context_Bytes := 0;
      end Begin_Selected_Group;

      procedure Find_Line_Matches
        (Text         : String;
         Matched      : out Boolean;
         First_Column : out Positive;
         Count        : out Natural;
         Emit_Matches : Boolean;
         Rendered     : out Unbounded_String;
         Json_Matches : out Unbounded_String);

      procedure Find_Line_Matches
        (Text         : String;
         Matched      : out Boolean;
         First_Column : out Positive;
         Count        : out Natural;
         Emit_Matches : Boolean;
         Rendered     : out Unbounded_String;
         Json_Matches : out Unbounded_String)
      is
         type Capture_Array is array (Positive range <>) of Regexp.Capture_Buffer;
         type Capture_Count_Array is array (Positive range <>) of Natural;
         Cursors    : Posix_Tools.Commands.Rg.Patterns.Match_Cursor_Array (Patterns'Range);
         Candidates : Regexp.Match_Result_Array (Patterns'Range);
         Captures   : Capture_Array (Patterns'Range);
         Capture_Counts : Capture_Count_Array (Patterns'Range) := [others => 0];
         Minimum    : Positive := 1;
         Copy_Position : Positive := 1;
         Replacement_Output : Unbounded_String;
         Replace_Line : constant Boolean :=
           Options.Replace_Matches
           and then not Options.Invert
           and then Options.Mode = Posix_Tools.Commands.Rg.Rendering.Matching_Lines;
         Highlight_Line : constant Boolean :=
           not Options.Replace_Matches
           and then not Options.Invert
           and then Options.Mode = Posix_Tools.Commands.Rg.Rendering.Matching_Lines;

         procedure Advance (Index : Positive);
         procedure Replacement_Failed;

         procedure Replacement_Failed is
         begin
            if not Outcome.Match_Error then
               Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                 (Context, "replacement output exceeds the 64 MiB limit in "
                  & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
               Outcome.Match_Error := True;
            end if;
         end Replacement_Failed;

         procedure Advance (Index : Positive) is
         begin
            Posix_Tools.Commands.Rg.Patterns.Next_With_Captures
              (Cursors (Index),
               Text,
               Candidates (Index),
               Captures (Index),
               Capture_Counts (Index));
            if Candidates (Index).Status not in Regexp.Match_Ok | Regexp.No_Match then
               if Options.Abort_Callback /= null and then Options.Abort_Callback.all then
                  Outcome.Stop_All := True;
               else
                  Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                    (Context, "matching limit exceeded in "
                     & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                  Outcome.Match_Error := True;
               end if;
            end if;
         end Advance;
      begin
         Matched := False;
         First_Column := 1;
         Count := 0;
         Rendered := Null_Unbounded_String;
         Json_Matches := Null_Unbounded_String;
         for Index in Patterns'Range loop
            Posix_Tools.Commands.Rg.Patterns.Start
              (Patterns (Index), Cursors (Index), Options.Abort_Callback);
            Advance (Index);
         end loop;

         while not Outcome.Match_Error
           and then not Outcome.Stop_All
           and then not Context.Output_Failed
         loop
            for Index in Candidates'Range loop
               while Candidates (Index).Status = Regexp.Match_Ok
                 and then Candidates (Index).First < Minimum
               loop
                  Advance (Index);
                  exit when Outcome.Match_Error;
               end loop;
            end loop;
            exit when Outcome.Match_Error;

            declare
               Best : Natural := 0;
            begin
               for Index in Candidates'Range loop
                  if Candidates (Index).Status = Regexp.Match_Ok
                    and then
                      (Best = 0
                       or else Candidates (Index).First < Candidates (Best).First)
                  then
                     Best := Index;
                  end if;
               end loop;
               exit when Best = 0;

               declare
                  Found : Regexp.Match_Result renames Candidates (Best);
                  Match_Text : Unbounded_String;
                  Json_Replacement : Unbounded_String;
                  Replacement_Status : Posix_Tools.Commands.Rg.Patterns.Replacement_Status;
               begin
                  if not Matched then
                     First_Column := Found.First;
                  end if;
                  Matched := True;
                  Count := Count + 1;

                  if Options.Json_Output then
                     if Options.Replace_Matches then
                        Posix_Tools.Commands.Rg.Patterns.Append_Replacement
                          (Patterns (Best),
                           Text,
                           Found,
                           Captures (Best),
                           Capture_Counts (Best),
                           To_String (Options.Replacement),
                           Json_Replacement,
                           Maximum_Replacement_Bytes,
                           Replacement_Status);
                        if Replacement_Status
                          = Posix_Tools.Commands.Rg.Patterns.Replacement_Too_Large
                        then
                           Replacement_Failed;
                        end if;
                     end if;
                     if not Outcome.Match_Error then
                        if Length (Json_Matches) > 0 then
                           Append (Json_Matches, ',');
                        end if;
                        Append
                          (Json_Matches,
                           Posix_Tools.Commands.Rg.Json.Submatch
                             ((if Found.Last >= Found.First
                               then Text
                                 (Text'First + Found.First - 1
                                  .. Text'First + Found.Last - 1)
                               else ""),
                              Found.First - 1,
                              (if Found.Last >= Found.First then Found.Last else Found.First - 1),
                              To_String (Json_Replacement),
                              Options.Replace_Matches));
                     end if;
                  end if;

                  if Replace_Line or else Highlight_Line then
                     if Found.First > Copy_Position then
                        if Found.First - Copy_Position
                          > Maximum_Replacement_Bytes - Length (Replacement_Output)
                        then
                           Replacement_Failed;
                        else
                           declare
                              Chunk : constant String :=
                                Text
                                  (Text'First + Copy_Position - 1
                                   .. Text'First + Found.First - 2);
                           begin
                              Append
                                (Replacement_Output,
                                 (if Highlight_Line
                                  then Posix_Tools.Commands.Rg.Rendering.Highlight_Text
                                    (Chunk, Options.Style)
                                  else Chunk));
                           end;
                        end if;
                     end if;
                     if Replace_Line and then not Outcome.Match_Error then
                        Posix_Tools.Commands.Rg.Patterns.Append_Replacement
                          (Patterns (Best),
                           Text,
                           Found,
                           Captures (Best),
                           Capture_Counts (Best),
                           To_String (Options.Replacement),
                           Replacement_Output,
                           Maximum_Replacement_Bytes,
                           Replacement_Status);
                        if Replacement_Status
                          = Posix_Tools.Commands.Rg.Patterns.Replacement_Too_Large
                        then
                           Replacement_Failed;
                        end if;
                     elsif Highlight_Line
                       and then Found.Last >= Found.First
                       and then not Outcome.Match_Error
                     then
                        Append
                          (Replacement_Output,
                           Posix_Tools.Commands.Rg.Rendering.Highlight_Match
                             (Text
                                (Text'First + Found.First - 1
                                 .. Text'First + Found.Last - 1),
                              Options.Style));
                     end if;
                     Copy_Position :=
                       (if Found.Last >= Found.First then Found.Last + 1 else Found.First);
                  end if;

                  if Options.Mode = Posix_Tools.Commands.Rg.Rendering.Only_Matching
                    and then Emit_Matches
                    and then not
                      (Options.Binary = Search_Binary
                       and then Saw_Nul
                       and then not Options.Json_Output)
                  then
                     Begin_Output;
                     if Options.Replace_Matches then
                        Posix_Tools.Commands.Rg.Patterns.Append_Replacement
                          (Patterns (Best),
                           Text,
                           Found,
                           Captures (Best),
                           Capture_Counts (Best),
                           To_String (Options.Replacement),
                           Match_Text,
                           Maximum_Replacement_Bytes,
                           Replacement_Status);
                        if Replacement_Status
                          = Posix_Tools.Commands.Rg.Patterns.Replacement_Too_Large
                        then
                           Replacement_Failed;
                        end if;
                     elsif Found.Last >= Found.First then
                        Match_Text := To_Unbounded_String
                          (Text (Text'First + Found.First - 1 .. Text'First + Found.Last - 1));
                     end if;
                     Posix_Tools.Commands.Rg.Rendering.Put_Selected_Line
                       (Context,
                        Label,
                        Match_Text,
                        Line_Number => Number,
                        Column      => Found.First,
                        Style       => Result_Style,
                        Count_Output => Record_Output'Access,
                        Highlight   => not Options.Replace_Matches);
                  end if;

                  Minimum :=
                    (if Found.Last >= Found.First then Found.Last + 1 else Found.First + 1);
                  Advance (Best);
               end;
            end;
         end loop;

         if (Replace_Line or else Highlight_Line) and then not Outcome.Match_Error then
            if Copy_Position <= Text'Length then
               if Text'Length - Copy_Position + 1
                 > Maximum_Replacement_Bytes - Length (Replacement_Output)
               then
                  Replacement_Failed;
               else
                  declare
                     Chunk : constant String :=
                       Text (Text'First + Copy_Position - 1 .. Text'Last);
                  begin
                     Append
                       (Replacement_Output,
                        (if Highlight_Line
                         then Posix_Tools.Commands.Rg.Rendering.Highlight_Text
                           (Chunk, Options.Style)
                         else Chunk));
                  end;
               end if;
            end if;
            Rendered := Replacement_Output;
         elsif not Replace_Line and then not Highlight_Line then
            Rendered := To_Unbounded_String (Text);
         end if;
      end Find_Line_Matches;

      procedure Search_Multiline is
         Data  : Unbounded_String;
         Lines : Multiline_Line_Vectors.Vector;
         Spans : Match_Span_Vectors.Vector;
         Event_Span_Index : Positive := 1;
         Record_Terminator : constant Character :=
           (if Options.Null_Data then ASCII.NUL else ASCII.LF);

         type Replacement_Group is record
            First_Line   : Positive;
            Last_Line    : Positive;
            Output_Line  : Positive;
            Start_Column : Positive;
            Text         : Unbounded_String;
         end record;

         package Replacement_Group_Vectors is new Ada.Containers.Vectors
           (Index_Type   => Positive,
            Element_Type => Replacement_Group);

         Groups : Replacement_Group_Vectors.Vector;
         Render_Replacements : constant Boolean :=
           Options.Replace_Matches
           and then not Options.Invert
           and then Options.Mode in
             Posix_Tools.Commands.Rg.Rendering.Matching_Lines
             | Posix_Tools.Commands.Rg.Rendering.Only_Matching;

         function Last_Offset (Item : Multiline_Line) return Natural is
           (Item.First
            + Length (Item.Text)
            + (if Item.Terminated then 1 else 0)
            - 1);

         function Line_At (Position : Positive) return Natural;
         function Highlighted_Line (Line_Index : Positive) return Unbounded_String;
         procedure Mark_Match
           (First        : Positive;
            Last         : Natural;
            Start_Line   : Positive;
            Start_Column : Positive);
         procedure Put_Match_Fragments (Line_Index : Positive);
         procedure Build_Replacement_Groups (Text : String);
         procedure Put_Replacement_Groups (Line_Index : Positive);
         procedure Put_Replacement_Matches (Line_Index : Positive);
         procedure Put_Json_Match_Event
           (First_Span : Positive;
            Last_Span  : Positive;
            First_Line : Positive;
            Last_Line  : Positive);
         procedure Put_Replacement_Text
           (Text         : Unbounded_String;
            Line_Number  : Positive;
            Column       : Positive;
            Emit_Empty   : Boolean);

         function Line_At (Position : Positive) return Natural is
         begin
            if Lines.Is_Empty then
               return 0;
            end if;
            for Index in Lines.First_Index .. Lines.Last_Index loop
               if Position in Lines.Element (Index).First .. Last_Offset (Lines.Element (Index)) then
                  return Index;
               end if;
            end loop;
            return 0;
         end Line_At;

         procedure Put_Json_Match_Event
           (First_Span : Positive;
            Last_Span  : Positive;
            First_Line : Positive;
            Last_Line  : Positive)
         is
            Block_First : constant Positive := Lines.Element (First_Line).First;
            Block : Unbounded_String;
            Submatches : Unbounded_String;
         begin
            for Line_Index in First_Line .. Last_Line loop
               declare
                  Item : constant Multiline_Line := Lines.Element (Line_Index);
               begin
                  Append (Block, Item.Text);
                  if Item.Terminated then
                     Append (Block, Record_Terminator);
                  end if;
               end;
            end loop;

            for Span_Index in First_Span .. Last_Span loop
               declare
                  Span : constant Match_Span := Spans.Element (Span_Index);
                  Start_Offset : constant Natural := Span.First - Block_First;
                  End_Offset : constant Natural :=
                    (if Span.Last >= Span.First
                     then Span.Last - Block_First + 1
                     else Start_Offset);
                  Matched : constant String :=
                    (if Span.Last >= Span.First
                     then Slice (Data, Span.First, Span.Last)
                     else "");
               begin
                  if Length (Submatches) > 0 then
                     Append (Submatches, ',');
                  end if;
                  Append
                    (Submatches,
                     Posix_Tools.Commands.Rg.Json.Submatch
                       (Matched,
                        Start_Offset,
                        End_Offset,
                        To_String (Span.Replacement),
                        Options.Replace_Matches));
               end;
            end loop;

            declare
               First_Item : constant Multiline_Line := Lines.Element (First_Line);
               Output : constant String :=
                 Posix_Tools.Commands.Rg.Json.Line_Event
                   ("match",
                    Label,
                    To_String (Block),
                    False,
                    First_Item.Number,
                    Block_First - 1,
                    To_String (Submatches))
                 & ASCII.LF;
            begin
               Context.Put (Output);
               Record_Output (Output'Length);
            end;
         end Put_Json_Match_Event;

         function Highlighted_Line (Line_Index : Positive) return Unbounded_String is
            Item : constant Multiline_Line := Lines.Element (Line_Index);
            Position : Positive := 1;
            Result : Unbounded_String;
         begin
            if Length (Item.Text) = 0 then
               return Item.Text;
            end if;

            declare
               Content_Last : constant Natural := Item.First + Length (Item.Text) - 1;
            begin
               for Span of Spans loop
                  if Span.First <= Content_Last
                    and then Span.Last >= Item.First
                    and then Span.Last >= Span.First
                  then
                     declare
                        Fragment_First : constant Positive := Positive'Max (Span.First, Item.First);
                        Fragment_Last  : constant Natural := Natural'Min (Span.Last, Content_Last);
                        Local_First    : constant Positive := Fragment_First - Item.First + 1;
                        Local_Last     : constant Natural := Fragment_Last - Item.First + 1;
                     begin
                        if Local_Last >= Local_First then
                           if Local_First > Position then
                              Append
                                (Result,
                                 Posix_Tools.Commands.Rg.Rendering.Highlight_Text
                                   (Slice (Item.Text, Position, Local_First - 1), Options.Style));
                           end if;
                           Append
                             (Result,
                              Posix_Tools.Commands.Rg.Rendering.Highlight_Match
                                (Slice (Item.Text, Local_First, Local_Last), Options.Style));
                           Position := Local_Last + 1;
                        end if;
                     end;
                  end if;
               end loop;
            end;

            if Position <= Length (Item.Text) then
               Append
                 (Result,
                  Posix_Tools.Commands.Rg.Rendering.Highlight_Text
                    (Slice (Item.Text, Position, Length (Item.Text)), Options.Style));
            end if;
            return Result;
         end Highlighted_Line;

         procedure Mark_Match
           (First        : Positive;
            Last         : Natural;
            Start_Line   : Positive;
            Start_Column : Positive)
         is
            Effective_Last : constant Positive :=
              (if Last >= First then Last else First);
         begin
            for Index in Lines.First_Index .. Lines.Last_Index loop
               declare
                  Item : Multiline_Line := Lines.Element (Index);
               begin
                  if Item.First <= Effective_Last and then Last_Offset (Item) >= First then
                     Item.Matched := True;
                     if not Item.Column_Set then
                        Item.Column := Start_Column;
                        Item.Column_Set := True;
                     end if;
                     Lines.Replace_Element (Index, Item);
                  end if;
               end;
            end loop;

            declare
               Item : Multiline_Line := Lines.Element (Start_Line);
            begin
               Item.Starts_Match := True;
               Lines.Replace_Element (Start_Line, Item);
            end;
         end Mark_Match;

         procedure Put_Match_Fragments (Line_Index : Positive) is
            Item : constant Multiline_Line := Lines.Element (Line_Index);
            Content_Last : constant Natural := Item.First + Length (Item.Text) - 1;
         begin
            if Length (Item.Text) = 0 then
               return;
            end if;
            for Span of Spans loop
               if Span.First <= Content_Last
                 and then Span.Last >= Item.First
                 and then Span.Last >= Span.First
               then
                  declare
                     Fragment_First : constant Positive := Positive'Max (Span.First, Item.First);
                     Fragment_Last  : constant Natural := Natural'Min (Span.Last, Content_Last);
                  begin
                     if Fragment_Last >= Fragment_First then
                        Posix_Tools.Commands.Rg.Rendering.Put_Selected_Line
                          (Context,
                           Label,
                           To_Unbounded_String
                             (Slice
                                (Item.Text,
                                 Fragment_First - Item.First + 1,
                                 Fragment_Last - Item.First + 1)),
                           Line_Number => Item.Number,
                           Column      => Span.Start_Column,
                           Style       => Result_Style,
                           Count_Output => Record_Output'Access,
                           Highlight   => True);
                     end if;
                  end;
               end if;
            end loop;
         end Put_Match_Fragments;

         procedure Put_Replacement_Text
           (Text         : Unbounded_String;
            Line_Number  : Positive;
            Column       : Positive;
            Emit_Empty   : Boolean)
         is
            Value : constant String := To_String (Text);
            First : Positive := 1;
            Number : Positive := Line_Number;
         begin
            if Value'Length = 0 then
               if Emit_Empty then
                  Posix_Tools.Commands.Rg.Rendering.Put_Selected_Line
                    (Context,
                     Label,
                     Null_Unbounded_String,
                     Number,
                     Column,
                     Result_Style,
                     Record_Output'Access);
               end if;
               return;
            end if;

            for Position in Value'Range loop
               if Value (Position) = Record_Terminator then
                  Posix_Tools.Commands.Rg.Rendering.Put_Selected_Line
                    (Context,
                     Label,
                     To_Unbounded_String (Value (First .. Position - 1)),
                     Number,
                     Column,
                     Result_Style,
                     Record_Output'Access);
                  First := Position + 1;
                  Number := Number + 1;
               end if;
            end loop;

            if First <= Value'Last then
               Posix_Tools.Commands.Rg.Rendering.Put_Selected_Line
                 (Context,
                  Label,
                  To_Unbounded_String (Value (First .. Value'Last)),
                  Number,
                  Column,
                  Result_Style,
                  Record_Output'Access);
            end if;
         end Put_Replacement_Text;

         procedure Build_Replacement_Groups (Text : String) is
            Span_Index  : Positive := Spans.First_Index;
            Total_Bytes : Natural := 0;

            function Gap_Has_Line_Break
              (Left, Right : Match_Span) return Boolean
            is
               First : constant Positive :=
                 (if Left.Last >= Left.First then Left.Last + 1 else Left.First);
               Last  : constant Natural := Right.First - 1;
            begin
               if Last < First then
                  return False;
               end if;
               for Position in First .. Last loop
                  if Text (Text'First + Position - 1) = Record_Terminator then
                     return True;
                  end if;
               end loop;
               return False;
            end Gap_Has_Line_Break;

            procedure Append_Bounded
              (Output : in out Unbounded_String;
               Value  : String)
            is
            begin
               if Value'Length > Maximum_Replacement_Bytes - Total_Bytes then
                  Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                    (Context, "replacement output exceeds the 64 MiB limit in "
                     & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                  Outcome.Match_Error := True;
               else
                  Append (Output, Value);
                  Total_Bytes := Total_Bytes + Value'Length;
               end if;
            end Append_Bounded;
         begin
            if Spans.Is_Empty then
               return;
            end if;

            while Span_Index <= Spans.Last_Index and then not Outcome.Match_Error loop
               declare
                  First_Span : constant Positive := Span_Index;
                  Last_Span  : Positive := Span_Index;
               begin
                  while Last_Span < Spans.Last_Index
                    and then not Gap_Has_Line_Break
                      (Spans.Element (Last_Span), Spans.Element (Last_Span + 1))
                  loop
                     Last_Span := Last_Span + 1;
                  end loop;

                  declare
                     First_Match : constant Match_Span := Spans.Element (First_Span);
                     Last_Match  : constant Match_Span := Spans.Element (Last_Span);
                     Last_Item   : constant Multiline_Line := Lines.Element (Last_Match.End_Line);
                     Content_Last : constant Natural :=
                       Last_Item.First + Length (Last_Item.Text) - 1;
                     Copy_Position : Positive := Lines.Element (First_Match.Start_Line).First;
                     Output : Unbounded_String;
                  begin
                     for Index in First_Span .. Last_Span loop
                        declare
                           Span : constant Match_Span := Spans.Element (Index);
                        begin
                           if Span.First > Copy_Position then
                              Append_Bounded
                                (Output,
                                 Text
                                   (Text'First + Copy_Position - 1
                                    .. Text'First + Span.First - 2));
                           end if;
                           if not Outcome.Match_Error then
                              Append_Bounded (Output, To_String (Span.Replacement));
                           end if;
                           Copy_Position :=
                             (if Span.Last >= Span.First then Span.Last + 1 else Span.First);
                        end;
                        exit when Outcome.Match_Error;
                     end loop;

                     if not Outcome.Match_Error and then Copy_Position <= Content_Last then
                        Append_Bounded
                          (Output,
                           Text
                             (Text'First + Copy_Position - 1
                              .. Text'First + Content_Last - 1));
                     end if;

                     if not Outcome.Match_Error then
                        Groups.Append
                          (Replacement_Group'
                             (First_Line   => First_Match.Start_Line,
                              Last_Line    => Last_Match.End_Line,
                              Output_Line  => First_Match.Output_Line,
                              Start_Column => First_Match.Start_Column,
                              Text         => Output));
                     end if;
                  end;
                  Span_Index := Last_Span + 1;
               end;
            end loop;
         end Build_Replacement_Groups;

         procedure Put_Replacement_Groups (Line_Index : Positive) is
         begin
            for Group of Groups loop
               if Group.First_Line = Line_Index then
                  Put_Replacement_Text
                    (Group.Text,
                     Group.Output_Line,
                     Group.Start_Column,
                     Emit_Empty => True);
               end if;
            end loop;
         end Put_Replacement_Groups;

         procedure Put_Replacement_Matches (Line_Index : Positive) is
         begin
            for Span of Spans loop
               if Span.Start_Line = Line_Index then
                  Put_Replacement_Text
                    (Span.Replacement,
                     Span.Output_Line,
                     Span.Start_Column,
                     Emit_Empty => False);
               end if;
            end loop;
         end Put_Replacement_Matches;
      begin
         loop
            declare
               Line       : Unbounded_String;
               Terminated : Boolean;
               Nul_Offset : Natural;
               Status     : Posix_Tools.Commands.Rg.Input.Read_Outcome;
            begin
               Posix_Tools.Commands.Rg.Input.Next
                 (Reader, Context, Line, Terminated, Nul_Offset, Status, Record_Terminator);
               pragma Unreferenced (Nul_Offset);

               case Status is
                  when Posix_Tools.Commands.Rg.Input.End_Of_Input =>
                     exit;
                  when Posix_Tools.Commands.Rg.Input.Read_Failed =>
                     Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                       (Context, "read failed for "
                        & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                     Outcome.Input_Error := True;
                     return;
                  when Posix_Tools.Commands.Rg.Input.Line_Too_Long =>
                     Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                       (Context, "line exceeds the 4 MiB search limit in "
                        & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                     Outcome.Input_Error := True;
                     return;
                  when Posix_Tools.Commands.Rg.Input.Line_Available =>
                     declare
                        Extra : constant Natural :=
                          Length (Line) + (if Terminated then 1 else 0);
                     begin
                        if Extra > Maximum_Multiline_Bytes - Length (Data) then
                           Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                             (Context, "multiline input exceeds the 64 MiB buffer limit in "
                              & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                           Outcome.Input_Error := True;
                           return;
                        end if;
                        Lines.Append
                          (Multiline_Line'
                             (Number      => Positive (Natural (Lines.Length) + 1),
                              Text        => Line,
                              First       => Length (Data) + 1,
                              Terminated  => Terminated,
                              others      => <>));
                        Append (Data, Line);
                        if Terminated then
                           Append (Data, Record_Terminator);
                        end if;
                     end;
               end case;
            end;
         end loop;

         Outcome.Bytes_Searched := Length (Data);

         if not Lines.Is_Empty and then Length (Data) > 0 then
            declare
               type Capture_Array is array (Positive range <>) of Regexp.Capture_Buffer;
               type Capture_Count_Array is array (Positive range <>) of Natural;
               Text       : constant String := To_String (Data);
               Cursors    : Posix_Tools.Commands.Rg.Patterns.Match_Cursor_Array (Patterns'Range);
               Candidates : Regexp.Match_Result_Array (Patterns'Range);
               Captures   : Capture_Array (Patterns'Range);
               Capture_Counts : Capture_Count_Array (Patterns'Range) := [others => 0];
               Minimum    : Positive := 1;
               Line_Delta : Integer := 0;
               Replacement_Bytes : Natural := 0;

               function Line_Break_Count (First, Last : Natural) return Natural;
               function Line_Break_Count (Value : Unbounded_String) return Natural;

               procedure Advance (Index : Positive);

               function Line_Break_Count (First, Last : Natural) return Natural is
                  Result : Natural := 0;
               begin
                  if First = 0 or else Last < First then
                     return 0;
                  end if;
                  for Position in First .. Last loop
                     if Text (Text'First + Position - 1) = Record_Terminator then
                        Result := Result + 1;
                     end if;
                  end loop;
                  return Result;
               end Line_Break_Count;

               function Line_Break_Count (Value : Unbounded_String) return Natural is
                  Result : Natural := 0;
               begin
                  for Item of To_String (Value) loop
                     if Item = Record_Terminator then
                        Result := Result + 1;
                     end if;
                  end loop;
                  return Result;
               end Line_Break_Count;

               procedure Advance (Index : Positive) is
               begin
                  Posix_Tools.Commands.Rg.Patterns.Next_With_Captures
                    (Cursors (Index),
                     Text,
                     Candidates (Index),
                     Captures (Index),
                     Capture_Counts (Index));
                  if Candidates (Index).Status not in Regexp.Match_Ok | Regexp.No_Match then
                     if Options.Abort_Callback /= null and then Options.Abort_Callback.all then
                        Outcome.Stop_All := True;
                     else
                        Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                          (Context, "matching limit exceeded in "
                           & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                        Outcome.Match_Error := True;
                     end if;
                  end if;
               end Advance;
            begin
               for Index in Patterns'Range loop
                  Posix_Tools.Commands.Rg.Patterns.Start
                    (Patterns (Index), Cursors (Index), Options.Abort_Callback);
                  Advance (Index);
               end loop;

               while not Outcome.Match_Error and then not Outcome.Stop_All loop
                  for Index in Candidates'Range loop
                     while Candidates (Index).Status = Regexp.Match_Ok
                       and then Candidates (Index).First < Minimum
                     loop
                        Advance (Index);
                        exit when Outcome.Match_Error;
                     end loop;
                  end loop;
                  exit when Outcome.Match_Error;

                  declare
                     Best : Natural := 0;
                  begin
                     for Index in Candidates'Range loop
                        if Candidates (Index).Status = Regexp.Match_Ok
                          and then
                            (Best = 0
                             or else Candidates (Index).First < Candidates (Best).First)
                        then
                           Best := Index;
                        end if;
                     end loop;
                     exit when Best = 0;

                     declare
                        Found      : Regexp.Match_Result renames Candidates (Best);
                        Start_Line : constant Natural := Line_At (Found.First);
                        Include_Match : constant Boolean := Start_Line /= 0;
                     begin
                        if Include_Match and then not Options.Invert then
                           if not Lines.Element (Start_Line).Starts_Match
                             and then Selected_Count >= Options.Max_Count
                           then
                              exit;
                           elsif not Lines.Element (Start_Line).Starts_Match then
                              Selected_Count := Selected_Count + 1;
                           end if;
                        end if;

                        if Include_Match then
                           declare
                              Start_Item : constant Multiline_Line := Lines.Element (Start_Line);
                              Start_Column : constant Positive := Found.First - Start_Item.First + 1;
                              Effective_Last : constant Positive :=
                                (if Found.Last >= Found.First then Found.Last else Found.First);
                              End_Line : constant Positive := Positive (Line_At (Effective_Last));
                              Replacement_Text : Unbounded_String;
                              Replacement_Status :
                                Posix_Tools.Commands.Rg.Patterns.Replacement_Status;
                           begin
                              if Match_Total = Natural'Last then
                                 Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                                   (Context, "match count exceeds the supported limit in "
                                    & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                                 Outcome.Match_Error := True;
                              else
                                 if Render_Replacements then
                                    Posix_Tools.Commands.Rg.Patterns.Append_Replacement
                                      (Patterns (Best),
                                       Text,
                                       Found,
                                       Captures (Best),
                                       Capture_Counts (Best),
                                       To_String (Options.Replacement),
                                       Replacement_Text,
                                       Maximum_Replacement_Bytes - Replacement_Bytes,
                                       Replacement_Status);
                                    if Replacement_Status
                                      = Posix_Tools.Commands.Rg.Patterns.Replacement_Too_Large
                                    then
                                       Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                                         (Context, "replacement output exceeds the 64 MiB limit in "
                                          & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                                       Outcome.Match_Error := True;
                                    else
                                       Replacement_Bytes :=
                                         Replacement_Bytes + Length (Replacement_Text);
                                    end if;
                                 end if;
                                 Match_Total := Match_Total + 1;
                                 Mark_Match (Found.First, Found.Last, Start_Line, Start_Column);
                                 if not Outcome.Match_Error then
                                    Spans.Append
                                      (Match_Span'
                                         (First        => Found.First,
                                          Last         => Found.Last,
                                          Start_Line   => Start_Line,
                                          End_Line     => End_Line,
                                          Start_Column => Start_Column,
                                          Output_Line  => Positive (Integer (Start_Line) + Line_Delta),
                                          Replacement  => Replacement_Text));
                                    if Render_Replacements then
                                       Line_Delta :=
                                         Line_Delta
                                         + Integer (Line_Break_Count (Replacement_Text))
                                         - Integer
                                           (Line_Break_Count (Found.First, Found.Last));
                                    end if;
                                 end if;
                              end if;
                           end;
                        end if;

                        Minimum :=
                          (if Found.Last >= Found.First then Found.Last + 1 else Found.First + 1);
                        Advance (Best);
                     end;
                  end;
               end loop;
            end;
         end if;

         if Outcome.Match_Error then
            return;
         end if;

         if Render_Replacements then
            Build_Replacement_Groups (To_String (Data));
            if Outcome.Match_Error then
               return;
            end if;
         end if;

         if Options.Invert then
            Selected_Count := 0;
            for Index in Lines.First_Index .. Lines.Last_Index loop
               declare
                  Item : Multiline_Line := Lines.Element (Index);
               begin
                  if not Item.Matched and then Selected_Count < Options.Max_Count then
                     Item.Selected := True;
                     Selected_Count := Selected_Count + 1;
                  end if;
                  Lines.Replace_Element (Index, Item);
               end;
            end loop;
         else
            for Index in Lines.First_Index .. Lines.Last_Index loop
               declare
                  Item : Multiline_Line := Lines.Element (Index);
               begin
                  Item.Selected := Item.Matched;
                  Lines.Replace_Element (Index, Item);
               end;
            end loop;
         end if;

         Outcome.Match_Count := (if Options.Invert then 0 else Match_Total);
         Outcome.Matched_Lines := 0;
         for Item of Lines loop
            if Item.Selected then
               Outcome.Matched_Lines := Added (Outcome.Matched_Lines, 1);
            end if;
         end loop;

         Outcome.Had_Match := Selected_Count > 0;
         if not Outcome.Had_Match then
            return;
         end if;

         if Options.Binary = Search_Binary
           and then Saw_Nul
           and then not Options.Json_Output
           and then Options.Mode in
             Posix_Tools.Commands.Rg.Rendering.Matching_Lines
             | Posix_Tools.Commands.Rg.Rendering.Only_Matching
         then
            Put_Binary_Match;
            Outcome.Had_Result := True;
            return;
         end if;

         case Options.Mode is
            when Posix_Tools.Commands.Rg.Rendering.Quiet =>
               Outcome.Had_Result := True;
               Outcome.Stop_All := not Options.Collect_Statistics;
               return;
            when Posix_Tools.Commands.Rg.Rendering.Count_Lines
               | Posix_Tools.Commands.Rg.Rendering.Count_Matches =>
               Outcome.Had_Result := True;
               return;
            when Posix_Tools.Commands.Rg.Rendering.Files_With_Matches =>
               Posix_Tools.Commands.Rg.Rendering.Put_Path
                 (Context,
                  Label,
                  (if Options.Style.Null_Pathnames then ASCII.NUL else ASCII.LF),
                  Options.Style);
               Outcome.Had_Result := True;
               return;
            when Posix_Tools.Commands.Rg.Rendering.Files_Without_Match =>
               return;
            when others =>
               null;
         end case;

         if Context_Active then
            for Index in Lines.First_Index .. Lines.Last_Index loop
               if Lines.Element (Index).Selected then
                  declare
                     First : constant Positive :=
                       (if Index > Options.Before_Context
                        then Index - Options.Before_Context
                        else Lines.First_Index);
                     Last : constant Positive :=
                       Positive'Min
                         (Lines.Last_Index,
                          Index + Natural'Min
                            (Options.After_Context, Lines.Last_Index - Index));
                  begin
                     for Context_Index in First .. Last loop
                        declare
                           Item : Multiline_Line := Lines.Element (Context_Index);
                        begin
                           Item.Show := True;
                           Lines.Replace_Element (Context_Index, Item);
                        end;
                     end loop;
                  end;
               end if;
            end loop;
         else
            for Index in Lines.First_Index .. Lines.Last_Index loop
               declare
                  Item : Multiline_Line := Lines.Element (Index);
               begin
                  Item.Show := Item.Selected;
                  Lines.Replace_Element (Index, Item);
               end;
            end loop;
         end if;

         for Index in Lines.First_Index .. Lines.Last_Index loop
            declare
               Item : constant Multiline_Line := Lines.Element (Index);
            begin
               if Item.Show then
                  if not Have_Output_Group then
                     Begin_Output;
                     if Context_Active
                       and then Options.Separate_First_Group
                       and then not Options.Style.Heading
                       and then not Options.Json_Output
                     then
                        Posix_Tools.Commands.Rg.Rendering.Put_Context_Separator
                          (Context,
                           To_String (Options.Context_Separator),
                           Options.Style.Record_Terminator,
                           Record_Output'Access,
                           Options.Style);
                     end if;
                  elsif Context_Active
                    and then Item.Number > Last_Output_Number + 1
                    and then not Options.Json_Output
                  then
                     Posix_Tools.Commands.Rg.Rendering.Put_Context_Separator
                       (Context,
                        To_String (Options.Context_Separator),
                        Options.Style.Record_Terminator,
                        Record_Output'Access,
                        Options.Style);
                  end if;

                  if Item.Selected then
                     if Options.Json_Output and then Options.Invert then
                        declare
                           Output : constant String :=
                             Posix_Tools.Commands.Rg.Json.Line_Event
                               ("match",
                                Label,
                                To_String (Item.Text),
                                Item.Terminated,
                                Item.Number,
                                Item.First - 1,
                                "")
                             & ASCII.LF;
                        begin
                           Context.Put (Output);
                           Record_Output (Output'Length);
                        end;
                     elsif Options.Json_Output
                       and then Event_Span_Index <= Spans.Last_Index
                       and then Spans.Element (Event_Span_Index).Start_Line = Index
                     then
                        declare
                           First_Span : constant Positive := Event_Span_Index;
                           Last_Span  : Positive := Event_Span_Index;
                           Last_Line  : Positive := Spans.Element (Event_Span_Index).End_Line;
                           All_Empty  : Boolean :=
                             Spans.Element (Event_Span_Index).Last
                               < Spans.Element (Event_Span_Index).First;
                        begin
                           while Last_Span < Spans.Last_Index loop
                              declare
                                 Next : constant Match_Span := Spans.Element (Last_Span + 1);
                                 Next_Empty : constant Boolean := Next.Last < Next.First;
                              begin
                                 exit when Next.Start_Line > Last_Line
                                   and then not
                                     (All_Empty
                                      and then Next_Empty
                                      and then Next.Start_Line = Last_Line + 1);
                                 Last_Span := Last_Span + 1;
                                 Last_Line := Positive'Max (Last_Line, Next.End_Line);
                                 All_Empty := All_Empty and Next_Empty;
                              end;
                           end loop;
                           Put_Json_Match_Event (First_Span, Last_Span, Index, Last_Line);
                           Event_Span_Index := Last_Span + 1;
                           Last_Output_Number := Last_Line;
                        end;
                     elsif Options.Json_Output then
                        null;
                     elsif Options.Mode = Posix_Tools.Commands.Rg.Rendering.Only_Matching
                       and then not Options.Invert
                     then
                        if Options.Replace_Matches then
                           Put_Replacement_Matches (Index);
                        else
                           Put_Match_Fragments (Index);
                        end if;
                     elsif Options.Replace_Matches and then not Options.Invert then
                        Put_Replacement_Groups (Index);
                     else
                        declare
                           Style : Posix_Tools.Commands.Rg.Rendering.Format := Result_Style;
                        begin
                           if Options.Invert then
                              Style.Show_Column := False;
                           end if;
                           Posix_Tools.Commands.Rg.Rendering.Put_Selected_Line
                             (Context,
                              Label,
                              (if Options.Invert then Item.Text else Highlighted_Line (Index)),
                              Item.Number,
                              Item.Column,
                              Style,
                              Record_Output'Access,
                              Logical_Length => Length (Item.Text));
                        end;
                     end if;
                     Outcome.Had_Result := True;
                  else
                     Put_Context_Line
                       (Item.Text, Item.Number, Item.First - 1, Item.Terminated);
                  end if;
                  Have_Output_Group := True;
                  Last_Output_Number := Natural'Max (Last_Output_Number, Item.Number);
               end if;
            end;
         end loop;
      end Search_Multiline;
   begin
      Outcome := (others => <>);
      Posix_Tools.Commands.Rg.Diagnostics.Trace
        (Context, Options.Diagnostics, "rg::search", "preparing " & Label);
      if not Options.Null_Data
        and then Name = "-"
        and then Options.Binary /= Treat_As_Text
      then
         declare
            Spool_Status : Posix_Tools.Commands.Rg.Input.Spool_Outcome;
         begin
            Posix_Tools.Commands.Rg.Input.Open_Spooled_Standard_Input
              (Reader, Context, Options.Encoding, First_Nul_Offset, Spool_Status);
            case Spool_Status is
               when Posix_Tools.Commands.Rg.Input.Spool_Ready =>
                  Opened := True;
                  Saw_Nul :=
                    First_Nul_Offset /= Posix_Tools.Commands.Rg.Input.No_Nul_Byte;
                  if Saw_Nul then
                     Posix_Tools.Commands.Rg.Diagnostics.Trace
                       (Context,
                        Options.Diagnostics,
                        "rg::search",
                        Label & ": binary byte at offset" & Natural'Image (First_Nul_Offset));
                  end if;
               when Posix_Tools.Commands.Rg.Input.Spool_Read_Failed =>
                  Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                    (Context, "read failed for "
                     & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                  Outcome.Input_Error := True;
                  return;
               when Posix_Tools.Commands.Rg.Input.Spool_Capacity_Exceeded =>
                  Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                    (Context, "standard input exceeds the 1 GiB spool limit");
                  Outcome.Input_Error := True;
                  return;
               when others =>
                  Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                    (Context, "cannot buffer "
                     & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                  Outcome.Input_Error := True;
                  return;
            end case;

            if Options.Binary = Detect_Binary
              and then Saw_Nul
              and then not Options.Json_Output
            then
               Posix_Tools.Commands.Rg.Diagnostics.Debug
                 (Context, Options.Diagnostics, "rg::search", "ignoring " & Label & ": binary data");
               Posix_Tools.Commands.Rg.Input.Close (Reader, Closed);
               if not Closed then
                  Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                    (Context, "close failed for "
                     & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                  Outcome.Input_Error := True;
               end if;
               return;
            end if;
         end;
      elsif not Options.Null_Data
        and then Name /= "-"
        and then Options.Binary /= Treat_As_Text
      then
         declare
            Scan_Status : Posix_Tools.Commands.Rg.Input.Nul_Scan_Outcome;
         begin
            Posix_Tools.Commands.Rg.Input.Scan_File_For_Nul
              (Name, Options.Encoding, First_Nul_Offset, Scan_Status);
            case Scan_Status is
               when Posix_Tools.Commands.Rg.Input.No_Nul_Found =>
                  null;
               when Posix_Tools.Commands.Rg.Input.Nul_Found =>
                  Saw_Nul := True;
                  Posix_Tools.Commands.Rg.Diagnostics.Trace
                    (Context,
                     Options.Diagnostics,
                     "rg::search",
                     Label & ": binary byte at offset" & Natural'Image (First_Nul_Offset));
                  if Options.Binary = Detect_Binary
                    and then not Options.Json_Output
                  then
                     Posix_Tools.Commands.Rg.Diagnostics.Debug
                       (Context, Options.Diagnostics, "rg::search", "ignoring " & Label & ": binary data");
                     return;
                  end if;
               when others =>
                  Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                    (Context, "cannot read "
                     & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                  Outcome.Input_Error := True;
                  return;
            end case;
         end;
      end if;

      if not Opened then
         Posix_Tools.Commands.Rg.Input.Open (Reader, Name, Options.Encoding, Opened);
      end if;
      if not Opened then
         Posix_Tools.Commands.Rg.Diagnostics.Error_Line
           (Context, "cannot read " & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
         Outcome.Input_Error := True;
         return;
      end if;
      Outcome.Was_Searched := True;
      Posix_Tools.Commands.Rg.Diagnostics.Trace
        (Context,
         Options.Diagnostics,
         "rg::search",
         "searching " & Label & " with "
         & (if Options.Multiline then "multiline" else "line")
         & " strategy and " & Posix_Tools.Commands.Rg.Input.Encoding_Mode'Image (Options.Encoding));

      if Options.Multiline then
         Search_Multiline;
      else
         while Selected_Count < Options.Max_Count
           or else (Context_Active and then After_Remaining > 0)
         loop
            declare
               Line       : Unbounded_String;
               Terminated : Boolean;
               Nul_Offset : Natural;
               Status     : Posix_Tools.Commands.Rg.Input.Read_Outcome;
               Matched    : Boolean := False;
               Selected   : Boolean;
               Column     : Positive := 1;
               Line_Matches : Natural := 0;
               Output_Current : Boolean := False;
               Rendered_Line : Unbounded_String;
               Json_Matches  : Unbounded_String;

               procedure Put_Selected;

               procedure Put_Selected is
                  Style : Posix_Tools.Commands.Rg.Rendering.Format := Result_Style;
                  Ignored_Matched : Boolean;
                  Ignored_Column  : Positive;
                  Ignored_Count   : Natural;
                  Ignored_Rendered : Unbounded_String;
                  Ignored_Json : Unbounded_String;
               begin
                  Begin_Output;
                  if Options.Invert then
                     Style.Show_Column := False;
                  end if;

                  if Options.Mode = Posix_Tools.Commands.Rg.Rendering.Only_Matching
                    and then not Options.Invert
                  then
                     Find_Line_Matches
                       (To_String (Line),
                        Ignored_Matched,
                        Ignored_Column,
                        Ignored_Count,
                        Emit_Matches => True,
                        Rendered     => Ignored_Rendered,
                        Json_Matches => Ignored_Json);
                  elsif Options.Json_Output then
                     declare
                        Output : constant String :=
                          Posix_Tools.Commands.Rg.Json.Line_Event
                            ("match",
                             Label,
                             To_String (Line),
                             Terminated,
                             Number,
                             Byte_Offset,
                             To_String (Json_Matches),
                             (if Options.Null_Data then ASCII.NUL else ASCII.LF))
                          & ASCII.LF;
                     begin
                        Context.Put (Output);
                        Record_Output (Output'Length);
                     end;
                  else
                     Posix_Tools.Commands.Rg.Rendering.Put_Selected_Line
                       (Context,
                        Label,
                        (if Options.Invert then Line else Rendered_Line),
                        Line_Number => Number,
                        Column      => Column,
                        Style       => Style,
                        Count_Output => Record_Output'Access,
                        Logical_Length =>
                          (if Options.Replace_Matches
                           then Length (Rendered_Line)
                           else Length (Line)));
                  end if;
                  Outcome.Had_Result := True;
                  Have_Output_Group := True;
                  Last_Output_Number := Number;
                  Output_Current := True;
               end Put_Selected;
            begin
               Posix_Tools.Commands.Rg.Input.Next
                 (Reader,
                  Context,
                  Line,
                  Terminated,
                  Nul_Offset,
                  Status,
                  (if Options.Null_Data then ASCII.NUL else ASCII.LF));

               if Nul_Offset /= Posix_Tools.Commands.Rg.Input.No_Nul_Byte then
                  if not Saw_Nul then
                     First_Nul_Offset := Added (Byte_Offset, Nul_Offset);
                  end if;
                  Saw_Nul := True;
               end if;

               if Options.Binary = Detect_Binary
                 and then Saw_Nul
                 and then not Options.Json_Output
               then
                  exit;
               end if;

               case Status is
                  when Posix_Tools.Commands.Rg.Input.End_Of_Input =>
                     exit;
                  when Posix_Tools.Commands.Rg.Input.Read_Failed =>
                     Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                       (Context, "read failed for "
                        & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                     Outcome.Input_Error := True;
                     exit;
                  when Posix_Tools.Commands.Rg.Input.Line_Too_Long =>
                     Number := Number + 1;
                     Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                       (Context, "line exceeds the 4 MiB search limit in "
                        & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                     Outcome.Input_Error := True;
                     Before_Lines.Clear;
                     Context_Bytes := 0;
                     After_Remaining := 0;
                  when Posix_Tools.Commands.Rg.Input.Line_Available =>
                     Number := Number + 1;
                     if Options.Mode in
                       Posix_Tools.Commands.Rg.Rendering.Count_Matches
                       | Posix_Tools.Commands.Rg.Rendering.Only_Matching
                       or else Options.Replace_Matches
                       or else Options.Collect_Statistics
                       or else
                         (Options.Mode = Posix_Tools.Commands.Rg.Rendering.Matching_Lines
                          and then not Options.Invert)
                     then
                        Find_Line_Matches
                          (To_String (Line),
                           Matched,
                           Column,
                           Line_Matches,
                           Emit_Matches => not Context_Active,
                           Rendered     => Rendered_Line,
                           Json_Matches => Json_Matches);
                     else
                        for Pattern of Patterns loop
                           declare
                              Match : constant Regexp.Match_Result :=
                                Posix_Tools.Commands.Rg.Patterns.Find_First
                                  (Pattern,
                                   To_String (Line),
                                   Abort_Callback => Options.Abort_Callback);
                           begin
                              if Match.Status = Regexp.Match_Ok then
                                 if not Matched or else Match.First < Column then
                                    Column := Match.First;
                                 end if;
                                 Matched := True;
                              elsif Match.Status /= Regexp.No_Match
                                and then Options.Abort_Callback /= null
                                and then Options.Abort_Callback.all
                              then
                                 Outcome.Stop_All := True;
                                 exit;
                              elsif Match.Status /= Regexp.No_Match then
                                 Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                                   (Context, "matching limit exceeded in "
                                    & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                                 Outcome.Match_Error := True;
                                 exit;
                              end if;
                           end;
                        end loop;
                     end if;

                     if Options.Collect_Statistics
                       and then not Options.Invert
                       and then Matched
                     then
                        Outcome.Match_Count := Added (Outcome.Match_Count, Line_Matches);
                     end if;

                     Selected := (if Options.Invert then not Matched else Matched);
                     if Selected
                       and then Selected_Count < Options.Max_Count
                       and then not Outcome.Match_Error
                     then
                        Selected_Count := Selected_Count + 1;
                        Outcome.Matched_Lines := Added (Outcome.Matched_Lines, 1);
                        Outcome.Had_Match := True;
                        if Options.Binary = Search_Binary
                          and then Saw_Nul
                          and then not Options.Json_Output
                          and then Options.Mode in
                            Posix_Tools.Commands.Rg.Rendering.Matching_Lines
                            | Posix_Tools.Commands.Rg.Rendering.Only_Matching
                        then
                           Outcome.Had_Result := True;
                           Put_Binary_Match;
                        else
                           if Context_Active then
                              Begin_Selected_Group;
                              Put_Selected;
                              After_Remaining := Options.After_Context;
                           else
                              case Options.Mode is
                              when Posix_Tools.Commands.Rg.Rendering.Matching_Lines =>
                                 Outcome.Had_Result := True;
                                 Begin_Output;
                                 if Options.Json_Output then
                                    declare
                                       Output : constant String :=
                                         Posix_Tools.Commands.Rg.Json.Line_Event
                                           ("match",
                                            Label,
                                            To_String (Line),
                                            Terminated,
                                            Number,
                                            Byte_Offset,
                                            To_String (Json_Matches),
                                            (if Options.Null_Data then ASCII.NUL else ASCII.LF))
                                         & ASCII.LF;
                                    begin
                                       Context.Put (Output);
                                       Record_Output (Output'Length);
                                    end;
                                 else
                                    declare
                                       Style : Posix_Tools.Commands.Rg.Rendering.Format := Result_Style;
                                    begin
                                       if Options.Invert then
                                          Style.Show_Column := False;
                                       end if;
                                       Posix_Tools.Commands.Rg.Rendering.Put_Selected_Line
                                         (Context,
                                          Label,
                                          (if Options.Invert then Line else Rendered_Line),
                                          Line_Number => Number,
                                          Column      => Column,
                                          Style       => Style,
                                          Count_Output => Record_Output'Access,
                                          Logical_Length =>
                                            (if Options.Replace_Matches
                                             then Length (Rendered_Line)
                                             else Length (Line)));
                                    end;
                                 end if;
                              when Posix_Tools.Commands.Rg.Rendering.Quiet =>
                                 Outcome.Had_Result := True;
                                 Outcome.Stop_All := not Options.Collect_Statistics;
                              when Posix_Tools.Commands.Rg.Rendering.Count_Lines =>
                                 Outcome.Had_Result := True;
                              when Posix_Tools.Commands.Rg.Rendering.Count_Matches =>
                                 Outcome.Had_Result := True;
                                 if Line_Matches > Natural'Last - Match_Total then
                                    Posix_Tools.Commands.Rg.Diagnostics.Error_Line
                                      (Context, "match count exceeds the supported limit in "
                                       & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
                                    Outcome.Match_Error := True;
                                 else
                                    Match_Total := Match_Total + Line_Matches;
                                 end if;
                              when Posix_Tools.Commands.Rg.Rendering.Only_Matching =>
                                 Outcome.Had_Result := True;
                              when Posix_Tools.Commands.Rg.Rendering.Files_With_Matches =>
                                 Outcome.Had_Result := True;
                                 Posix_Tools.Commands.Rg.Rendering.Put_Path
                                   (Context,
                                    Label,
                                    (if Options.Null_Data or else Options.Style.Null_Pathnames
                                     then ASCII.NUL
                                     else ASCII.LF),
                                    Options.Style);
                              when Posix_Tools.Commands.Rg.Rendering.Files_Without_Match =>
                                 null;
                              end case;
                           end if;
                        end if;
                        if Context.Output_Failed then
                           Outcome.Output_Error := True;
                           exit;
                        end if;
                        exit when Options.Mode in
                          Posix_Tools.Commands.Rg.Rendering.Files_With_Matches
                          | Posix_Tools.Commands.Rg.Rendering.Files_Without_Match
                          or else
                            (Options.Mode = Posix_Tools.Commands.Rg.Rendering.Quiet
                             and then not Options.Collect_Statistics)
                          or else
                            (Options.Binary = Search_Binary
                             and then Saw_Nul
                             and then not Options.Json_Output
                             and then Options.Mode in
                               Posix_Tools.Commands.Rg.Rendering.Matching_Lines
                               | Posix_Tools.Commands.Rg.Rendering.Only_Matching);
                     elsif Context_Active
                       and then After_Remaining > 0
                       and then not Outcome.Match_Error
                     then
                        if Selected then
                           Put_Selected;
                        else
                           Put_Context_Line (Line, Number, Byte_Offset, Terminated);
                           Output_Current := True;
                        end if;
                        After_Remaining := After_Remaining - 1;
                     end if;

                     if Context_Active
                       and then not Output_Current
                       and then After_Remaining = 0
                       and then not Outcome.Input_Error
                       and then not Outcome.Match_Error
                     then
                        Buffer_Context_Line (Line, Byte_Offset, Terminated);
                     end if;
               end case;

               Byte_Offset := Added (Byte_Offset, Length (Line));
               if Terminated then
                  Byte_Offset := Added (Byte_Offset, 1);
               end if;
               Outcome.Bytes_Searched := Byte_Offset;

               exit when Outcome.Match_Error or else Context_Buffer_Failed;
            end;
         end loop;
      end if;

      Posix_Tools.Commands.Rg.Input.Close (Reader, Closed);
      if not Closed then
         Posix_Tools.Commands.Rg.Diagnostics.Error_Line
           (Context, "close failed for " & Posix_Tools.Commands.Helpers.Escape_Untrusted (Label));
         Outcome.Input_Error := True;
      end if;

      if Options.Max_Count > 0
        and then not Outcome.Input_Error
        and then not Outcome.Match_Error
      then
         case Options.Mode is
            when Posix_Tools.Commands.Rg.Rendering.Count_Lines =>
               if Outcome.Had_Match then
                  Posix_Tools.Commands.Rg.Rendering.Put_Count
                    (Context, Label, Selected_Count, Options.Style);
               end if;
            when Posix_Tools.Commands.Rg.Rendering.Count_Matches =>
               if Outcome.Had_Match then
                  Posix_Tools.Commands.Rg.Rendering.Put_Count
                    (Context, Label, Match_Total, Options.Style);
               end if;
            when Posix_Tools.Commands.Rg.Rendering.Files_Without_Match =>
               if not Outcome.Had_Match then
                  Posix_Tools.Commands.Rg.Rendering.Put_Path
                    (Context,
                     Label,
                     (if Options.Null_Data or else Options.Style.Null_Pathnames
                      then ASCII.NUL
                      else ASCII.LF),
                     Options.Style);
                  Outcome.Had_Result := True;
               end if;
            when others =>
               null;
         end case;
      end if;

      if Options.Json_Output
        and then Heading_Written
        and then Outcome.Had_Match
        and then not Context.Output_Failed
      then
         Context.Put_Line
           (Posix_Tools.Commands.Rg.Json.End_Event
              (Path => Label,
               Elapsed => Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - Started),
               Bytes_Searched => Outcome.Bytes_Searched,
               Bytes_Printed => Outcome.Bytes_Printed,
               Matched_Lines => Outcome.Matched_Lines,
               Matches => Outcome.Match_Count,
               Search_Had_Match => Outcome.Had_Match,
               Binary_Offset => First_Nul_Offset,
               Has_Binary_Offset => Saw_Nul));
      end if;

      Outcome.Output_Error := Outcome.Output_Error or else Context.Output_Failed;
      Posix_Tools.Commands.Rg.Diagnostics.Trace
        (Context,
         Options.Diagnostics,
         "rg::search",
         "finished " & Label & ":"
         & Natural'Image (Outcome.Matched_Lines) & " selected record(s),"
         & Natural'Image (Outcome.Bytes_Searched) & " byte(s) searched");
   end Search_Source;
end Posix_Tools.Commands.Rg.Search;
