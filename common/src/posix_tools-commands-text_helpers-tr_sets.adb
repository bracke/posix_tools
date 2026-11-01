with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Text.Base_Parsing;
with Posix_Tools.Text.Octal_Parsing;
with Posix_Tools.Text.UTF_8;

package body Posix_Tools.Commands.Text_Helpers.Tr_Sets is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   function Byte_Set (Text, Locale : String) return String is
      Output : Unbounded_String;
      I : Positive := Text'First;

      procedure Append_Range (Low, High : Character);

      function Bracket_Sequence
        (Marker : Character;
         Value  : out Unbounded_String;
         Last   : out Natural) return Boolean;

      function Decode_Escape (Index : in out Positive) return Character;

      function Decode_Set_Element (Index : in out Positive) return Character;

      function Repetition_Count
        (First : Positive;
         Last  : Natural;
         Count : out Natural) return Boolean;

      procedure Append_Range (Low, High : Character) is
      begin
         for Code in Character'Pos (Low) .. Character'Pos (High) loop
            Append (Output, Character'Val (Code));
         end loop;
      end Append_Range;

      function Bracket_Sequence
        (Marker : Character;
         Value  : out Unbounded_String;
         Last   : out Natural) return Boolean
      is
         Element_Index : Positive := I + 2;
      begin
         Value := Null_Unbounded_String;
         Last := 0;
         if I + 4 > Text'Last
           or else Text (I) /= '['
           or else Text (I + 1) /= Marker
         then
            return False;
         end if;

         while Element_Index + 1 <= Text'Last loop
            if Text (Element_Index) = Marker and then Text (Element_Index + 1) = ']' then
               Last := Element_Index + 1;
               return Length (Value) > 0;
            else
               Append (Value, Decode_Set_Element (Element_Index));
               Element_Index := Element_Index + 1;
            end if;
         end loop;

         return False;
      end Bracket_Sequence;

      function Decode_Escape (Index : in out Positive) return Character is
         Value : Natural := 0;
         Count : Natural := 0;
      begin
         if Index = Text'Last then
            return Text (Index);
         end if;

         Index := Index + 1;
         case Text (Index) is
            when '\' =>
               return '\';
            when 'a' =>
               return Character'Val (7);
            when 'b' =>
               return Character'Val (8);
            when 'f' =>
               return Character'Val (12);
            when 'n' =>
               return Character'Val (10);
            when 'r' =>
               return Character'Val (13);
            when 't' =>
               return Character'Val (9);
            when 'v' =>
               return Character'Val (11);
            when '0' .. '7' =>
               declare
                  Parsed : constant Posix_Tools.Text.Octal_Parsing.Parsed_Octal_Prefix :=
                    Posix_Tools.Text.Octal_Parsing.Prefix_Value
                      (Text (Index .. Text'Last), 3);
               begin
                  Count := Parsed.Count;
                  Value := Parsed.Value;
                  Index := Index + Count - 1;
                  return Character'Val (Natural'Min (Value, 255));
               end;
            when others =>
               return Text (Index);
         end case;
      end Decode_Escape;

      function Decode_Set_Element (Index : in out Positive) return Character is
      begin
         if Text (Index) = '\' then
            return Decode_Escape (Index);
         else
            return Text (Index);
         end if;
      end Decode_Set_Element;

      function Repetition_Count
        (First : Positive;
         Last  : Natural;
         Count : out Natural) return Boolean
      is
      begin
         Count := 0;
         if First > Last then
            return False;
         end if;

         declare
            Base   : constant Posix_Tools.Text.Base_Parsing.Number_Base :=
              (if First < Last and then Text (First) = '0' then 8 else 10);
            Parsed : constant Posix_Tools.Text.Base_Parsing.Parsed_Natural :=
              Posix_Tools.Text.Base_Parsing.Natural_Value (Text (First .. Last), Base);
         begin
            if not Parsed.Valid then
               return False;
            end if;
            Count := Parsed.Value;
            return True;
         end;
      end Repetition_Count;
   begin
      while I <= Text'Last loop
         if I + 8 <= Text'Last and then Text (I .. I + 8) = "[:lower:]" then
            Append_Range ('a', 'z');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:upper:]" then
            Append_Range ('A', 'Z');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:digit:]" then
            Append_Range ('0', '9');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:alnum:]" then
            Append_Range ('0', '9');
            Append_Range ('A', 'Z');
            Append_Range ('a', 'z');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:alpha:]" then
            Append_Range ('A', 'Z');
            Append_Range ('a', 'z');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:space:]" then
            Append (Output, Character'Val (9));
            Append (Output, Character'Val (10));
            Append (Output, Character'Val (11));
            Append (Output, Character'Val (12));
            Append (Output, Character'Val (13));
            Append (Output, ' ');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:blank:]" then
            Append (Output, Character'Val (9));
            Append (Output, ' ');
            I := I + 9;
         elsif I + 9 <= Text'Last and then Text (I .. I + 9) = "[:xdigit:]" then
            Append_Range ('0', '9');
            Append_Range ('A', 'F');
            Append_Range ('a', 'f');
            I := I + 10;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:punct:]" then
            Append_Range ('!', '/');
            Append_Range (':', '@');
            Append_Range ('[', '`');
            Append_Range ('{', '~');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:graph:]" then
            Append_Range ('!', '~');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:print:]" then
            Append_Range (' ', '~');
            I := I + 9;
         elsif I + 8 <= Text'Last and then Text (I .. I + 8) = "[:cntrl:]" then
            Append_Range (Character'Val (0), Character'Val (31));
            Append (Output, Character'Val (127));
            I := I + 9;
         elsif Text (I) = '[' and then I + 3 <= Text'Last then
            declare
               Sequence   : Unbounded_String;
               Last_Index : Natural;
               Element_Index : Positive := I + 1;
               Repeated      : Character;
               Star_Index    : Natural;
               Close_Index   : Natural := 0;
               Count         : Natural := 0;
               Handled       : Boolean := False;
            begin
               if Bracket_Sequence ('=', Sequence, Last_Index)
               then
                  Append (Output, Collation.Locale_Equivalence_Class (Locale, To_String (Sequence)));
                  I := Last_Index + 1;
                  Handled := True;
               elsif Bracket_Sequence ('.', Sequence, Last_Index) then
                  Append (Output, Collation.Locale_Collating_Symbol (Locale, To_String (Sequence)));
                  I := Last_Index + 1;
                  Handled := True;
               else
                  Repeated := Decode_Set_Element (Element_Index);
                  Star_Index := Element_Index + 1;
               end if;

               if not Handled
                 and then Close_Index = 0
                 and then Star_Index <= Text'Last
                 and then Text (Star_Index) = '*'
               then
                  for J in Star_Index + 1 .. Text'Last loop
                     if Text (J) = ']' then
                        Close_Index := J;
                        exit;
                     end if;
                  end loop;
               end if;

               if not Handled
                 and then Close_Index > Star_Index + 1
                 and then Repetition_Count (Star_Index + 1, Close_Index - 1, Count)
               then
                  for J in 1 .. Count loop
                     Append (Output, Repeated);
                  end loop;
                  I := Close_Index + 1;
               elsif not Handled
                 and then Close_Index = Star_Index + 1
               then
                  for J in 1 .. 256 loop
                     Append (Output, Repeated);
                  end loop;
                  I := Close_Index + 1;
               else
                  if not Handled then
                     Append (Output, Text (I));
                     I := I + 1;
                  end if;
               end if;
            end;
         else
            declare
               Element_Index : Positive := I;
               Low           : constant Character := Decode_Set_Element (Element_Index);
               Next_Index    : constant Natural := Element_Index + 1;
            begin
               if Next_Index <= Text'Last - 1 and then Text (Next_Index) = '-' then
                  declare
                     High_Index : Positive := Next_Index + 1;
                     High       : constant Character := Decode_Set_Element (High_Index);
                  begin
                     if Character'Pos (Low) <= Character'Pos (High) then
                        Append_Range (Low, High);
                     else
                        Append (Output, Low);
                        Append (Output, '-');
                        Append (Output, High);
                     end if;
                     I := High_Index + 1;
                  end;
               else
                  Append (Output, Low);
                  I := Next_Index;
               end if;
            end;
         end if;
      end loop;

      return To_String (Output);
   end Byte_Set;

   function Character_Set (Text, Locale : String) return Element_Vectors.Vector is
      Output : Element_Vectors.Vector;
      I      : Positive := Text'First;

      procedure Append_Bytes (Bytes : String);

      function Code_Point_Of (Element : String) return Long_Long_Integer;

      --  Reads one element at I: an escape or one character.
      function Next_Element return String;

      --  At a '[' that may start [c*n]; False leaves I unchanged.
      function Repetition return Boolean;

      procedure Append_Bytes (Bytes : String) is
      begin
         for Element of Split (Bytes, True) loop
            Output.Append (Element);
         end loop;
      end Append_Bytes;

      function Code_Point_Of (Element : String) return Long_Long_Integer is
         Width      : Natural;
         Code_Point : Long_Long_Integer;
      begin
         if Element = "" then
            return No_Code_Point;
         end if;
         Decode_At (Element, Element'First, True, Width, Code_Point);
         return (if Width = Element'Length then Code_Point else No_Code_Point);
      end Code_Point_Of;

      function Next_Element return String is
         First      : constant Positive := I;
         Width      : Natural;
         Code_Point : Long_Long_Integer;
      begin
         if Text (I) = '\' and then I < Text'Last then
            I := I + 1;
            if Text (I) in '0' .. '7' then
               while I < Text'Last and then I - First < 3 and then Text (I + 1) in '0' .. '7' loop
                  I := I + 1;
               end loop;
            end if;
            I := I + 1;
            return Byte_Set (Text (First .. I - 1), Locale);
         end if;
         Decode_At (Text, I, True, Width, Code_Point);
         I := I + Width;
         return Text (First .. I - 1);
      end Next_Element;

      function Repetition return Boolean is
         Start : constant Positive := I;
         Count : Natural := 0;
         Close : Natural := 0;
      begin
         I := I + 1;
         declare
            Repeated : constant String := Next_Element;
         begin
            if I <= Text'Last and then Text (I) = '*' then
               for J in I + 1 .. Text'Last loop
                  if Text (J) = ']' then
                     Close := J;
                     exit;
                  elsif Text (J) not in '0' .. '9' then
                     exit;
                  end if;
               end loop;
            end if;
            if Close = 0 then
               I := Start;
               return False;
            end if;

            --  [c*] fills; a count with a leading zero is octal.
            if Close = I + 1 then
               Count := 256;
            else
               declare
                  Parsed : constant Posix_Tools.Text.Base_Parsing.Parsed_Natural :=
                    Posix_Tools.Text.Base_Parsing.Natural_Value
                      (Text (I + 1 .. Close - 1), (if Text (I + 1) = '0' then 8 else 10));
               begin
                  if not Parsed.Valid then
                     I := Start;
                     return False;
                  end if;
                  Count := Parsed.Value;
               end;
            end if;
            for J in 1 .. Count loop
               Output.Append (Repeated);
            end loop;
            I := Close + 1;
            return True;
         end;
      end Repetition;
   begin
      while I <= Text'Last loop
         if Text (I) = '[' and then I < Text'Last and then Text (I + 1) in ':' | '=' | '.' then
            declare
               Marker : constant Character := Text (I + 1);
               Close  : Natural := 0;
            begin
               for J in I + 3 .. Text'Last - 1 loop
                  if Text (J) = Marker and then Text (J + 1) = ']' then
                     Close := J + 1;
                     exit;
                  end if;
               end loop;
               if Close = 0 then
                  Output.Append (Next_Element);
               else
                  Append_Bytes
                    (Byte_Set (Text (I .. Close), Locale));
                  I := Close + 1;
               end if;
            end;
         elsif Text (I) = '[' and then I + 2 <= Text'Last and then Repetition then
            null;
         else
            declare
               Low : constant String := Next_Element;
            begin
               if I < Text'Last and then Text (I) = '-' then
                  I := I + 1;
                  declare
                     High      : constant String := Next_Element;
                     Low_Code  : constant Long_Long_Integer := Code_Point_Of (Low);
                     High_Code : constant Long_Long_Integer := Code_Point_Of (High);
                  begin
                     if Low_Code /= No_Code_Point and then High_Code /= No_Code_Point and then Low_Code <= High_Code
                     then
                        for Code in Low_Code .. High_Code loop
                           if Code not in 16#D800# .. 16#DFFF# then
                              Output.Append (Posix_Tools.Text.UTF_8.Encode (Code));
                           end if;
                        end loop;
                     else
                        Append_Bytes (Low);
                        Output.Append ("-");
                        Append_Bytes (High);
                     end if;
                  end;
               else
                  Append_Bytes (Low);
               end if;
            end;
         end if;
      end loop;
      return Output;
   end Character_Set;

   procedure Decode_At
     (Text       : String;
      Index      : Positive;
      At_End     : Boolean;
      Width      : out Natural;
      Code_Point : out Long_Long_Integer)
   is
      Decoder : Posix_Tools.Text.UTF_8.Decoder;
      Status  : Posix_Tools.Text.UTF_8.Decode_Status;
   begin
      for I in Index .. Text'Last loop
         Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos (Text (I)), Status, Code_Point);
         if Status = Posix_Tools.Text.UTF_8.Complete then
            Width := I - Index + 1;
            return;
         elsif Status = Posix_Tools.Text.UTF_8.Invalid then
            Width := 1;
            Code_Point := No_Code_Point;
            return;
         end if;
      end loop;
      Width := (if At_End then 1 else 0);
      Code_Point := No_Code_Point;
   end Decode_At;

   function Operand_Set (Text, Locale : String; Multibyte : Boolean) return Element_Vectors.Vector is
     (if Multibyte then Character_Set (Text, Locale) else Split (Byte_Set (Text, Locale), False));

   function Split (Text : String; Multibyte : Boolean) return Element_Vectors.Vector is
      Output     : Element_Vectors.Vector;
      I          : Positive := Text'First;
      Width      : Natural := 1;
      Code_Point : Long_Long_Integer;
   begin
      while I <= Text'Last loop
         if Multibyte then
            Decode_At (Text, I, True, Width, Code_Point);
         end if;
         Output.Append (Text (I .. I + Width - 1));
         I := I + Width;
      end loop;
      return Output;
   end Split;
end Posix_Tools.Commands.Text_Helpers.Tr_Sets;
