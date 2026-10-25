with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with I18N.Collation;
with Posix_Tools.Text.Base_Parsing;
with Posix_Tools.Text.Octal_Parsing;

package body Posix_Tools.Commands.Text_Helpers.Collation is
   use Ada.Strings.Unbounded;

   procedure Append_UTF_8 (Output : in out Unbounded_String; Code_Point : Long_Long_Integer);

   function Locale_Collating_Symbol (Locale, Element : String) return String;

   function Locale_Equivalence_Class (Locale, Element : String) return String;

   procedure Append_UTF_8 (Output : in out Unbounded_String; Code_Point : Long_Long_Integer) is
   begin
      if Code_Point <= 16#7F# then
         Append (Output, Character'Val (Natural (Code_Point)));
      elsif Code_Point <= 16#7FF# then
         Append (Output, Character'Val (16#C0# + Natural (Code_Point / 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      elsif Code_Point <= 16#FFFF# then
         Append (Output, Character'Val (16#E0# + Natural (Code_Point / 4_096)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 64) mod 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      else
         Append (Output, Character'Val (16#F0# + Natural (Code_Point / 262_144)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 4_096) mod 64)));
         Append (Output, Character'Val (16#80# + Natural ((Code_Point / 64) mod 64)));
         Append (Output, Character'Val (16#80# + Natural (Code_Point mod 64)));
      end if;
   end Append_UTF_8;

   function Locale_Collating_Symbol (Locale, Element : String) return String is
      Family : constant String := Locale_Family (Locale);
   begin
      if Family = "es" and then Element = "ch" then
         return "ch";
      elsif Family = "es" and then Element = "ll" then
         return "ll";
      elsif Family = "da" and then Element = "aa" then
         return "aa";
      else
         return Element;
      end if;
   end Locale_Collating_Symbol;

   function Locale_Collation_Order (Locale, Set1 : String) return String is
      Family : constant String := Locale_Family (Locale);
      Output : Unbounded_String;
      Ordered : String (1 .. 256);
      Last    : Natural := 0;
      Spanish_After_Enye : constant String := "opqrstuvwxyzABCDEFGHIJKLMN";

      procedure Append_If_Available (Ch : Character);

      function Key (Ch : Character) return String;

      procedure Append_If_Available (Ch : Character) is
      begin
         if (for all Item of Set1 => Item /= Ch)
           and then (for all I in 1 .. Last => Ordered (I) /= Ch)
         then
            Last := Last + 1;
            Ordered (Last) := Ch;
         end if;
      end Append_If_Available;

      function Key (Ch : Character) return String is
      begin
         if I18N.Collation.Available
           and then not Posix_Tools.Commands.Text_Helpers.Is_Byte_Collation_Locale (Locale)
           and then Family /= "en"
         then
            return I18N.Collation.Sort_Key ([1 => Ch], Locale, I18N.Collation.Primary);
         else
            return [1 => Ch];
         end if;
      exception
         when Constraint_Error =>
            return [1 => Ch];
      end Key;
   begin
      if Family = "da" then
         for Ch in Character range 'a' .. 'z' loop
            Append_If_Available (Ch);
         end loop;
         Append_If_Available (Character'Val (16#C3#));
         Append_If_Available (Character'Val (16#A6#));
         Append_If_Available (Character'Val (16#B8#));
         Append_If_Available (Character'Val (16#A5#));
         for Ch in Character range 'A' .. 'Z' loop
            Append_If_Available (Ch);
         end loop;
      elsif Family = "es" then
         for Ch in Character range 'a' .. 'n' loop
            Append_If_Available (Ch);
         end loop;
         Append_If_Available (Character'Val (16#C3#));
         Append_If_Available (Character'Val (16#B1#));
         for Ch of Spanish_After_Enye loop
            Append_If_Available (Ch);
         end loop;
         Append_If_Available (Character'Val (16#91#));
         for Ch in Character range 'O' .. 'Z' loop
            Append_If_Available (Ch);
         end loop;
      end if;

      for Code in 0 .. 255 loop
         Append_If_Available (Character'Val (Code));
      end loop;

      if Family /= "da" and then Family /= "es" then
         for I in 2 .. Last loop
            declare
               Item : constant Character := Ordered (I);
               J    : Natural := I;
            begin
               while J > 1
                 and then (Key (Item) < Key (Ordered (J - 1))
                           or else (Key (Item) = Key (Ordered (J - 1)) and then Item < Ordered (J - 1)))
               loop
                  Ordered (J) := Ordered (J - 1);
                  J := J - 1;
               end loop;
               Ordered (J) := Item;
            end;
         end loop;
      end if;

      for I in 1 .. Last loop
         Append (Output, Ordered (I));
      end loop;

      return To_String (Output);
   end Locale_Collation_Order;

   function Locale_Equivalence_Class (Locale, Element : String) return String is
      Family : constant String := Locale_Family (Locale);
      Output : Unbounded_String;

      procedure Append_If_Equivalent (Candidate : String);

      function Equivalent (Candidate : String) return Boolean;

      procedure Append_If_Equivalent (Candidate : String) is
      begin
         if Equivalent (Candidate)
           and then Ada.Strings.Fixed.Index (To_String (Output), Candidate) = 0
         then
            Append (Output, Candidate);
         end if;
      end Append_If_Equivalent;

      function Equivalent (Candidate : String) return Boolean is
      begin
         return I18N.Collation.Available
           and then I18N.Collation.Compare
             (Candidate, Element, Locale, I18N.Collation.Primary) = 0;
      exception
         when Constraint_Error =>
            return False;
      end Equivalent;
   begin
      Append (Output, Element);
      for Code in Character'Pos ('A') .. Character'Pos ('Z') loop
         Append_If_Equivalent ([1 => Character'Val (Code)]);
      end loop;
      for Code in Character'Pos ('a') .. Character'Pos ('z') loop
         Append_If_Equivalent ([1 => Character'Val (Code)]);
      end loop;
      for Code in 16#00C0# .. 16#017F# loop
         declare
            Candidate : Unbounded_String;
         begin
            Append_UTF_8 (Candidate, Long_Long_Integer (Code));
            Append_If_Equivalent (To_String (Candidate));
         end;
      end loop;

      if Element = "a" then
         if Family = "da" then
            Append_If_Equivalent ("a");
            Append_If_Equivalent (Character'Val (16#C3#) & Character'Val (16#A1#));
            Append_If_Equivalent (Character'Val (16#C3#) & Character'Val (16#A0#));
            Append (Output, Character'Val (16#C3#) & Character'Val (16#A1#)
                    & Character'Val (16#C3#) & Character'Val (16#A0#));
         elsif Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#A1#));
         end if;
      elsif Element = "e" then
         if Family = "da" or else Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#A9#));
         end if;
      elsif Element = "o" then
         if Family = "da" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#B8#));
         elsif Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#B3#));
         end if;
      elsif Element = "A" then
         if Family = "da" or else Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#81#));
         end if;
      elsif Element = "E" then
         if Family = "da" or else Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#89#));
         end if;
      elsif Element = "O" then
         if Family = "da" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#98#));
         elsif Family = "es" then
            Append (Output, Character'Val (16#C3#) & Character'Val (16#93#));
         end if;
      end if;

      if Length (Output) > Element'Length then
         return To_String (Output);
      end if;

      return Element;
   end Locale_Equivalence_Class;

   function Locale_Family (Locale : String) return String is
      Dot : Natural := 0;
   begin
      for I in Locale'Range loop
         if Locale (I) = '.' or else Locale (I) = '_' or else Locale (I) = '-' then
            Dot := I - 1;
            exit;
         end if;
      end loop;

      if Dot = 0 then
         return Locale;
      elsif Dot < Locale'First then
         return "";
      else
         return Locale (Locale'First .. Dot);
      end if;
   end Locale_Family;

   function Locale_Sort_Text (Locale, Text : String) return String is
      Family : constant String := Locale_Family (Locale);
      Output : Unbounded_String;
      I      : Positive := Text'First;

      procedure Append_Byte_Order (Ch : Character);

      procedure Append_Collation (Primary, Secondary : Character);

      function Has_Bytes (Pattern : String) return Boolean;

      procedure Append_Byte_Order (Ch : Character) is
      begin
         Append (Output, Ch);
         Append (Output, Character'Val (0));
      end Append_Byte_Order;

      procedure Append_Collation (Primary, Secondary : Character) is
      begin
         Append (Output, Primary);
         Append (Output, Secondary);
      end Append_Collation;

      function Has_Bytes (Pattern : String) return Boolean is
      begin
         return I + Pattern'Length - 1 <= Text'Last
           and then Text (I .. I + Pattern'Length - 1) = Pattern;
      end Has_Bytes;
   begin
      if not Posix_Tools.Commands.Text_Helpers.Is_Byte_Collation_Locale (Locale)
        and then Family /= "da"
        and then Family /= "es"
        and then I18N.Collation.Available
      then
         declare
            CLDR_Key : constant String := I18N.Collation.Sort_Key (Text, Locale, I18N.Collation.Tertiary);
         begin
            if CLDR_Key /= Text then
               return CLDR_Key;
            end if;
         end;
      end if;

      if Family /= "da" and then Family /= "es" then
         return Text;
      end if;

      while I <= Text'Last loop
         if Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (166)) then
            Append_Collation ('{', 'a');
            I := I + 2;
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (134)) then
            Append_Collation ('{', 'A');
            I := I + 2;
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (184)) then
            Append_Collation ('{', 'b');
            I := I + 2;
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (152)) then
            Append_Collation ('{', 'B');
            I := I + 2;
         elsif Family = "da"
           and then (Has_Bytes (Character'Val (195) & Character'Val (165))
                     or else Has_Bytes (Character'Val (226) & Character'Val (132) & Character'Val (171)))
         then
            Append_Collation ('{', 'c');
            I := I + (if Character'Pos (Text (I)) = 195 then 2 else 3);
         elsif Family = "da" and then Has_Bytes (Character'Val (195) & Character'Val (133)) then
            Append_Collation ('{', 'C');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("ch") then
            Append_Collation ('c', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("Ch") then
            Append_Collation ('C', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("ll") then
            Append_Collation ('l', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes ("Ll") then
            Append_Collation ('L', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (177)) then
            Append_Collation ('n', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (145)) then
            Append_Collation ('N', '{');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (161)) then
            Append_Collation ('a', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (169)) then
            Append_Collation ('e', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (173)) then
            Append_Collation ('i', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (179)) then
            Append_Collation ('o', 'a');
            I := I + 2;
         elsif Family = "es" and then Has_Bytes (Character'Val (195) & Character'Val (186)) then
            Append_Collation ('u', 'a');
            I := I + 2;
         else
            Append_Byte_Order (Text (I));
            I := I + 1;
         end if;
      end loop;

      return To_String (Output);
   end Locale_Sort_Text;

   function Translation_Set_From_Spec (Text, Locale : String) return String is
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
                  Append (Output, Locale_Equivalence_Class (Locale, To_String (Sequence)));
                  I := Last_Index + 1;
                  Handled := True;
               elsif Bracket_Sequence ('.', Sequence, Last_Index) then
                  Append (Output, Locale_Collating_Symbol (Locale, To_String (Sequence)));
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
   end Translation_Set_From_Spec;
end Posix_Tools.Commands.Text_Helpers.Collation;
