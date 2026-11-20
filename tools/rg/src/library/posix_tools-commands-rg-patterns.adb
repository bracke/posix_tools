package body Posix_Tools.Commands.Rg.Patterns is
   use type Regexp.Compile_Status;
   use type Regexp.Copy_Status;
   use type Regexp.Pattern_Policy_Status;

   Ripgrep_Default_Policy : constant Regexp.Pattern_Policy :=
     (Allow_Backreferences => False,
      Allow_Lookaround     => False,
      Allow_Atomic         => False,
      others               => True);

   function Compile_Source
     (Source  : String;
      Options : Compile_Options;
      Anchored : Boolean)
      return Regexp.Compile_Result;

   function Byte_Mode_Wrapper (Source : String; Fixed : Boolean) return Boolean;
   function Effective_Source (Source : String; Fixed : Boolean) return String;
   function Effective_Mode
     (Source : String; Options : Compile_Options) return Regexp.Character_Mode_Type;

   function Byte_Mode_Wrapper (Source : String; Fixed : Boolean) return Boolean is
     (not Fixed
      and then Source'Length >= 7
      and then Source (Source'First .. Source'First + 4) = "(?-u:"
      and then Source (Source'Last) = ')');

   function Effective_Source (Source : String; Fixed : Boolean) return String is
     (if Byte_Mode_Wrapper (Source, Fixed)
      then Source (Source'First + 5 .. Source'Last - 1)
      else Source);

   function Effective_Mode
     (Source : String; Options : Compile_Options) return Regexp.Character_Mode_Type is
     (if Byte_Mode_Wrapper (Source, Options.Fixed_Strings)
      then Regexp.ASCII_Mode
      else Options.Character_Mode);

   function Normalize_Multiline_Escapes
     (Source  : String;
      Enabled : Boolean) return String;

   function Normalize_Named_Captures (Source : String) return String;

   function Normalize_Named_Captures (Source : String) return String is
      use Ada.Strings.Unbounded;
      Result   : Unbounded_String;
      Position : Integer := Source'First;
      In_Class : Boolean := False;
   begin
      while Position <= Source'Last loop
         if Source (Position) = '\' and then Position < Source'Last then
            Append (Result, Source (Position));
            Append (Result, Source (Position + 1));
            Position := Position + 2;
         elsif Source (Position) = '[' then
            In_Class := True;
            Append (Result, Source (Position));
            Position := Position + 1;
         elsif Source (Position) = ']' and then In_Class then
            In_Class := False;
            Append (Result, Source (Position));
            Position := Position + 1;
         elsif not In_Class
           and then Position <= Source'Last - 3
           and then Source (Position .. Position + 3) = "(?P<"
         then
            Append (Result, "(?<");
            Position := Position + 4;
         else
            Append (Result, Source (Position));
            Position := Position + 1;
         end if;
      end loop;
      return To_String (Result);
   end Normalize_Named_Captures;

   function Normalize_Multiline_Escapes
     (Source  : String;
      Enabled : Boolean) return String
   is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String;
      Index  : Integer := Source'First;
   begin
      if not Enabled then
         return Source;
      end if;

      while Index <= Source'Last loop
         if Source (Index) = '\'
           and then Index < Source'Last
           and then Source (Index + 1) = '\'
         then
            Append (Result, '\');
            Append (Result, '\');
            Index := Index + 2;
         elsif Source (Index) = '\'
           and then Index < Source'Last
           and then Source (Index + 1) = 'n'
         then
            Append (Result, ASCII.LF);
            Index := Index + 2;
         else
            Append (Result, Source (Index));
            Index := Index + 1;
         end if;
      end loop;
      return To_String (Result);
   end Normalize_Multiline_Escapes;

   function Compile_Source
     (Source   : String;
      Options  : Compile_Options;
      Anchored : Boolean)
      return Regexp.Compile_Result
   is
      Empty_Expression : constant String := "(?:)";
      Selected_Source  : constant String := Effective_Source (Source, Options.Fixed_Strings);
      Selected_Mode    : constant Regexp.Character_Mode_Type := Effective_Mode (Source, Options);
      Normalized       : constant String :=
        Normalize_Multiline_Escapes
          ((if Options.Fixed_Strings then Selected_Source else Normalize_Named_Captures (Selected_Source)),
           Options.Multiline_Anchors and then not Options.Fixed_Strings);
      Expression       : constant String :=
        (if Normalized = ""
         then Empty_Expression
         elsif Options.Fixed_Strings
         then Regexp.Escape_Literal (Normalized)
         else Normalized);
   begin
      if Anchored then
         return Regexp.Compile
           ("^(?:" & Expression & ")$", Character_Mode => Selected_Mode);
      else
         return Regexp.Compile
           (Expression, Character_Mode => Selected_Mode);
      end if;
   end Compile_Source;

   procedure Compile
     (Source     : String;
      Options    : Compile_Options;
      Pattern    : out Compiled_Pattern;
      Diagnostic : out Compile_Diagnostic)
   is
      Initial : constant Regexp.Compile_Result := Compile_Source (Source, Options, Anchored => False);
   begin
      Pattern := (others => <>);
      Diagnostic := (Engine_Status => Initial.Status, Error_Offset => Initial.Error_Offset, others => <>);

      if Initial.Status /= Regexp.Compile_Ok then
         return;
      end if;

      if not Options.Fixed_Strings then
         declare
            Policy : constant Regexp.Pattern_Policy_Diagnostic :=
              Regexp.Validate_Policy_Detail (Initial.Expression, Ripgrep_Default_Policy);
         begin
            if Policy.Status /= Regexp.Policy_Ok then
               Diagnostic.Status := Pattern_Disallowed;
               Diagnostic.Feature := Policy.Feature;
               return;
            end if;
         end;
      end if;

      declare
         Final : constant Regexp.Compile_Result :=
           (if Options.Whole_Line then Compile_Source (Source, Options, Anchored => True) else Initial);
      begin
         if Final.Status /= Regexp.Compile_Ok then
            Diagnostic.Engine_Status := Final.Status;
            Diagnostic.Error_Offset := Final.Error_Offset;
            return;
         end if;

         Pattern.Expression := Final.Expression;
         Pattern.Match :=
           (Case_Sensitive      => Options.Case_Handling = Sensitive,
            Whole_Word          => Options.Whole_Word,
            Dot_Matches_Newline => Options.Dot_Matches_Newline,
            Multiline_Anchors   => Options.Multiline_Anchors,
            Character_Mode      => Effective_Mode (Source, Options),
            others              => <>);
         Pattern.Capture_Offset := Options.Capture_Offset;
         Pattern.Valid := True;
         Diagnostic :=
           (Status        => Pattern_Ok,
            Engine_Status => Regexp.Compile_Ok,
            Error_Offset  => 0,
            Feature       => Regexp.Policy_Feature_None);
      end;
   end Compile;

   function Find_First
     (Pattern   : Compiled_Pattern;
      Text      : String;
      Max_Steps : Natural := Regexp.Default_Max_Steps;
      Abort_Callback : Regexp.Match_Abort_Callback := null)
      return Regexp.Match_Result
   is
      Options : Regexp.Match_Options := Pattern.Match;
   begin
      Options.Max_Steps := Max_Steps;
      Options.Abort_Callback := Abort_Callback;
      return Regexp.Find_First (Pattern.Expression, Text, Options);
   end Find_First;

   function Is_Valid (Pattern : Compiled_Pattern) return Boolean is
   begin
      return Pattern.Valid;
   end Is_Valid;

   function Capture_Count (Pattern : Compiled_Pattern) return Natural is
   begin
      return Regexp.Capture_Count (Pattern.Expression);
   end Capture_Count;

   function Capture_Name (Pattern : Compiled_Pattern; Index : Positive) return String is
      Buffer : String (1 .. Regexp.Max_Capture_Name_Length);
      Last   : Natural;
      Status : Regexp.Copy_Status;
   begin
      Regexp.Capture_Name (Pattern.Expression, Index, Buffer, Last, Status);
      return
        (if Status = Regexp.Copy_Ok and then Last > 0
         then Buffer (Buffer'First .. Last)
         else "");
   end Capture_Name;

   procedure Start
     (Pattern : Compiled_Pattern;
      Cursor  : out Match_Cursor;
      Abort_Callback : Regexp.Match_Abort_Callback := null) is
      Options : Regexp.Match_Options := Pattern.Match;
   begin
      Options.Abort_Callback := Abort_Callback;
      Regexp.Start (Cursor.Engine, Pattern.Expression, Options => Options);
   end Start;

   procedure Next
     (Cursor : in out Match_Cursor;
      Text   : String;
      Found  : out Regexp.Match_Result) is
   begin
      Regexp.Next (Cursor.Engine, Text, Found);
   end Next;

   procedure Next_With_Captures
     (Cursor   : in out Match_Cursor;
      Text     : String;
      Found    : out Regexp.Match_Result;
      Captures : out Regexp.Capture_Buffer;
      Count    : out Natural) is
   begin
      Regexp.Next_With_Captures (Cursor.Engine, Text, Found, Captures, Count);
   end Next_With_Captures;

   procedure Append_Replacement
     (Pattern        : Compiled_Pattern;
      Text           : String;
      Found          : Regexp.Match_Result;
      Captures       : Regexp.Capture_Buffer;
      Capture_Count  : Natural;
      Template       : String;
      Output         : in out Ada.Strings.Unbounded.Unbounded_String;
      Maximum_Length : Natural;
      Status         : out Replacement_Status)
   is
      use Ada.Strings.Unbounded;
      Position : Integer := Template'First;

      procedure Append_Bounded (Value : String);
      procedure Append_Capture (Name : String);

      procedure Append_Bounded (Value : String) is
      begin
         if Value'Length > Maximum_Length - Natural'Min (Length (Output), Maximum_Length) then
            Status := Replacement_Too_Large;
         else
            Append (Output, Value);
         end if;
      end Append_Bounded;

      procedure Append_Capture (Name : String) is
         Index : Natural := 0;
         Span  : Regexp.Text_Range;
      begin
         if Name = "0" then
            Span := (First => Found.First, Last => Found.Last);
         elsif Name'Length > 0
           and then (for all Item of Name => Item in '0' .. '9')
         then
            begin
               Index := Natural'Value (Name);
            exception
               when Constraint_Error =>
                  Index := 0;
            end;
            if Index > Pattern.Capture_Offset
              and then Index - Pattern.Capture_Offset in 1 .. Capture_Count
            then
               Span := Captures (Index - Pattern.Capture_Offset);
            else
               Span := (0, 0);
            end if;
         else
            Index := Regexp.Capture_Index (Pattern.Expression, Name);
            if Index in 1 .. Capture_Count then
               Span := Captures (Index);
            else
               Span := (0, 0);
            end if;
         end if;

         if Span.First > 0 and then Span.Last >= Span.First then
            Append_Bounded
              (Text
                 (Text'First + Span.First - 1
                  .. Text'First + Span.Last - 1));
         end if;
      end Append_Capture;
   begin
      Status := Replacement_Ok;
      while Position <= Template'Last and then Status = Replacement_Ok loop
         if Template (Position) /= '$' then
            Append_Bounded (String'(1 => Template (Position)));
            Position := Position + 1;
         elsif Position = Template'Last then
            Append_Bounded ("$");
            Position := Position + 1;
         elsif Template (Position + 1) = '$' then
            Append_Bounded ("$");
            Position := Position + 2;
         elsif Template (Position + 1) = '{' then
            declare
               Closing : Integer := Position + 2;
            begin
               while Closing <= Template'Last and then Template (Closing) /= '}' loop
                  Closing := Closing + 1;
               end loop;
               if Closing > Template'Last or else Closing = Position + 2 then
                  Append_Bounded ("$");
                  Position := Position + 1;
               else
                  Append_Capture (Template (Position + 2 .. Closing - 1));
                  Position := Closing + 1;
               end if;
            end;
         elsif Template (Position + 1) in 'A' .. 'Z'
           | 'a' .. 'z'
           | '0' .. '9'
           | '_'
         then
            declare
               Last : Integer := Position + 1;
            begin
               while Last < Template'Last
                 and then Template (Last + 1) in 'A' .. 'Z'
                   | 'a' .. 'z'
                   | '0' .. '9'
                   | '_'
               loop
                  Last := Last + 1;
               end loop;
               Append_Capture (Template (Position + 1 .. Last));
               Position := Last + 1;
            end;
         else
            Append_Bounded ("$");
            Position := Position + 1;
         end if;
      end loop;
   end Append_Replacement;
end Posix_Tools.Commands.Rg.Patterns;
