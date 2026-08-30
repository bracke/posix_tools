with Ada.Strings.Unbounded;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Text.Expr_Regex is
   use Ada.Strings.Unbounded;

   function Successful_Result (Value : String) return Match_Result is
   begin
      return (Status => Match_Valid, Value => To_Unbounded_String (Value));
   end Successful_Result;

   function Match (Text : String; Pattern : String) return Match_Result is
      type Match_State is record
         Seen_Capture  : Boolean := False;
         Capture_Start : Natural := 0;
         Capture_End   : Natural := 0;
      end record;

      Invalid_Expression : Boolean := False;

      procedure Mark_Invalid is
      begin
         Invalid_Expression := True;
      end Mark_Invalid;

      function Is_Group_Start (Index : Natural) return Boolean is
        (Index in Pattern'Range
         and then
           (Pattern (Index) = '('
            or else
              (Pattern (Index) = '\'
               and then Index < Pattern'Last
               and then Pattern (Index + 1) = '(')));

      function Is_Group_End (Index : Natural) return Boolean is
        (Index in Pattern'Range
         and then
           (Pattern (Index) = ')'
            or else
              (Pattern (Index) = '\'
               and then Index < Pattern'Last
               and then Pattern (Index + 1) = ')')));

      function Marker_Next (Index : Natural) return Natural is
        (if Pattern (Index) = '\' then Index + 2 else Index + 1);

      function Class_Close (Index : Natural) return Natural is
      begin
         if Index not in Pattern'Range or else Pattern (Index) /= '[' then
            return 0;
         end if;

         for I in Index + 1 .. Pattern'Last loop
            if Pattern (I) = ']' and then I > Index + 1 then
               if Pattern (I - 1) not in ':' | '=' | '.' then
                  return I;
               elsif I < Pattern'Last and then Pattern (I + 1) = ']' then
                  null;
               else
                  return I;
               end if;
            end if;
         end loop;

         return 0;
      end Class_Close;

      function Class_Matches (Index, Text_Index : Natural; Next_Text : out Natural) return Boolean is
         Close   : constant Natural := Class_Close (Index);
         Start   : Natural := Index + 1;
         Negated : Boolean := False;
         Matched : Boolean := False;
         Ch      : Character;

         function Starts_With (Prefix : String) return Boolean is
         begin
            return Prefix /= ""
              and then Text_Index + Prefix'Length - 1 <= Text'Last
              and then Text (Text_Index .. Text_Index + Prefix'Length - 1) = Prefix;
         end Starts_With;

         function Named_Class_Matches (Name : String) return Boolean is
         begin
            if Name = "alnum" then
               return Posix_Tools.Text.Byte_Classes.Is_ASCII_Alphanumeric (Ch);
            elsif Name = "alpha" then
               return Posix_Tools.Text.Byte_Classes.Is_ASCII_Alpha (Ch);
            elsif Name = "blank" then
               return Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Ch);
            elsif Name = "cntrl" then
               return Posix_Tools.Text.Byte_Classes.Is_ASCII_Control (Ch);
            elsif Name = "digit" then
               return Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Ch);
            elsif Name = "graph" then
               return Posix_Tools.Text.Byte_Classes.Is_ASCII_Graph (Ch);
            elsif Name = "lower" then
               return Posix_Tools.Text.Byte_Classes.Is_ASCII_Lower (Ch);
            elsif Name = "print" then
               return Posix_Tools.Text.Byte_Classes.Is_ASCII_Printable (Ch);
            elsif Name = "punct" then
               return Posix_Tools.Text.Byte_Classes.Is_ASCII_Punctuation (Ch);
            elsif Name = "space" then
               return Posix_Tools.Text.Byte_Classes.Is_POSIX_Space (Ch);
            elsif Name = "upper" then
               return Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper (Ch);
            elsif Name = "xdigit" then
               return Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit (Ch);
            else
               Mark_Invalid;
               return False;
            end if;
         end Named_Class_Matches;

         function Equivalence_Matches (Name : String) return Boolean is
         begin
            if Starts_With (Name) then
               Next_Text := Text_Index + Name'Length;
               return True;
            elsif Name'Length = 1 then
               return Ch = Name (Name'First);
            else
               return False;
            end if;
         end Equivalence_Matches;

         function Find_Named_End (Open : Natural; Delimiter : Character) return Natural is
         begin
            for I in Open + 2 .. Close - 2 loop
               if Pattern (I) = Delimiter and then Pattern (I + 1) = ']' then
                  return I;
               end if;
            end loop;
            return 0;
         end Find_Named_End;
      begin
         if Close = 0 then
            Mark_Invalid;
            return False;
         elsif Text_Index not in Text'Range then
            return False;
         end if;

         Ch := Text (Text_Index);
         Next_Text := Text_Index + 1;

         if Start < Close and then Pattern (Start) in '^' | '!' then
            Negated := True;
            Start := Start + 1;
         end if;

         while Start < Close loop
            if Start + 3 < Close
              and then Pattern (Start) = '['
              and then Pattern (Start + 1) in ':' | '=' | '.'
            then
               declare
                  Delimiter : constant Character := Pattern (Start + 1);
                  Named_End : constant Natural := Find_Named_End (Start, Delimiter);
               begin
                  if Named_End = 0 then
                     Mark_Invalid;
                     return False;
                  elsif Delimiter = ':' then
                     if Named_Class_Matches (Pattern (Start + 2 .. Named_End - 1)) then
                        Matched := True;
                     end if;
                  elsif Equivalence_Matches (Pattern (Start + 2 .. Named_End - 1)) then
                     Matched := True;
                  end if;
                  Start := Named_End + 2;
               end;
            elsif Start + 2 < Close and then Pattern (Start + 1) = '-' then
               if Ch >= Pattern (Start) and then Ch <= Pattern (Start + 2) then
                  Matched := True;
               end if;
               Start := Start + 3;
            else
               if Ch = Pattern (Start) then
                  Matched := True;
               end if;
               Start := Start + 1;
            end if;
         end loop;

         if Negated then
            Next_Text := Text_Index + 1;
            return not Matched;
         else
            return Matched;
         end if;
      end Class_Matches;

      function Atom_Next (Index : Natural) return Natural is
         Close : Natural;
      begin
         if Index not in Pattern'Range then
            Mark_Invalid;
            return Index;
         elsif Pattern (Index) = '[' then
            Close := Class_Close (Index);
            if Close = 0 then
               Mark_Invalid;
               return Index;
            end if;
            return Close + 1;
         elsif Pattern (Index) = '\' then
            if Index = Pattern'Last then
               Mark_Invalid;
               return Index;
            else
               return Index + 2;
            end if;
         else
            return Index + 1;
         end if;
      end Atom_Next;

      function Atom_Matches (Index, Text_Index : Natural; Next_Text : out Natural) return Boolean is
      begin
         Next_Text := Text_Index;
         if Text_Index not in Text'Range then
            return False;
         elsif Index not in Pattern'Range then
            Mark_Invalid;
            return False;
         elsif Pattern (Index) = '.' then
            Next_Text := Text_Index + 1;
            return True;
         elsif Pattern (Index) = '[' then
            return Class_Matches (Index, Text_Index, Next_Text);
         elsif Pattern (Index) = '\' then
            if Index = Pattern'Last then
               Mark_Invalid;
               return False;
            elsif Text (Text_Index) = Pattern (Index + 1) then
               Next_Text := Text_Index + 1;
               return True;
            else
               return False;
            end if;
         elsif Text (Text_Index) = Pattern (Index) then
            Next_Text := Text_Index + 1;
            return True;
         else
            return False;
         end if;
      end Atom_Matches;

      function Match_From
        (Pattern_Index : Natural;
         Text_Index    : Natural;
         State         : Match_State;
         Final_State   : out Match_State;
         End_Position  : out Natural) return Boolean;

      function Match_Star
        (Atom_Index   : Natural;
         Rest_Index   : Natural;
         Text_Index   : Natural;
         State        : Match_State;
         Final_State  : out Match_State;
         End_Position : out Natural) return Boolean
      is
         Next_Text : Natural;
      begin
         if Atom_Matches (Atom_Index, Text_Index, Next_Text) and then Next_Text > Text_Index then
            if Match_Star (Atom_Index, Rest_Index, Next_Text, State, Final_State, End_Position) then
               return True;
            end if;
         end if;

         return Match_From (Rest_Index, Text_Index, State, Final_State, End_Position);
      end Match_Star;

      function Match_From
        (Pattern_Index : Natural;
         Text_Index    : Natural;
         State         : Match_State;
         Final_State   : out Match_State;
         End_Position  : out Natural) return Boolean
      is
         Next_State : Match_State := State;
         Next_Index : Natural;
      begin
         if Pattern_Index > Pattern'Last then
            Final_State := State;
            End_Position := Text_Index - 1;
            return True;
         elsif Is_Group_Start (Pattern_Index) then
            if not Next_State.Seen_Capture then
               Next_State.Seen_Capture := True;
               Next_State.Capture_Start := Text_Index;
            end if;
            return Match_From (Marker_Next (Pattern_Index), Text_Index, Next_State, Final_State, End_Position);
         elsif Is_Group_End (Pattern_Index) and then Next_State.Seen_Capture then
            if Next_State.Capture_End = 0 then
               Next_State.Capture_End := Text_Index - 1;
            end if;
            return Match_From (Marker_Next (Pattern_Index), Text_Index, Next_State, Final_State, End_Position);
         else
            Next_Index := Atom_Next (Pattern_Index);
            if Invalid_Expression then
               Final_State := State;
               End_Position := 0;
               return False;
            elsif Next_Index <= Pattern'Last and then Pattern (Next_Index) = '*' then
               return Match_Star (Pattern_Index, Next_Index + 1, Text_Index, State, Final_State, End_Position);
            elsif Atom_Matches (Pattern_Index, Text_Index, Next_Index) then
               return Match_From (Atom_Next (Pattern_Index), Next_Index, State, Final_State, End_Position);
            else
               Final_State := State;
               End_Position := 0;
               return False;
            end if;
         end if;
      end Match_From;

      State        : Match_State;
      End_Position : Natural := 0;
   begin
      if not Match_From (Pattern'First, Text'First, (others => <>), State, End_Position) then
         if Invalid_Expression then
            return (Status => Match_Invalid_Expression, Value => Null_Unbounded_String);
         end if;
         return Successful_Result ("0");
      elsif Invalid_Expression
        or else (State.Seen_Capture and then State.Capture_Start > 0 and then State.Capture_End = 0)
      then
         return (Status => Match_Invalid_Expression, Value => Null_Unbounded_String);
      elsif State.Seen_Capture then
         if State.Capture_End < State.Capture_Start then
            return Successful_Result ("");
         else
            return Successful_Result (Text (State.Capture_Start .. State.Capture_End));
         end if;
      else
         return Successful_Result
           (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
              (if End_Position < Text'First then 0
               else Long_Long_Integer (End_Position - Text'First + 1)));
      end if;
   end Match;
end Posix_Tools.Text.Expr_Regex;
