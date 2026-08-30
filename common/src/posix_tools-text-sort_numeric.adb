with Ada.Strings.Unbounded;
with I18N.CLDR_Data;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Matching;

package body Posix_Tools.Text.Sort_Numeric is
   use Ada.Strings.Unbounded;

   function Locale_Digit_At
     (Locale : String;
      Text   : String;
      Index  : Positive;
      Digit  : out Character;
      Width  : out Natural) return Boolean;

   function Locale_Digit_At
     (Locale : String;
      Text   : String;
      Index  : Positive;
      Digit  : out Character;
      Width  : out Natural) return Boolean
   is
   begin
      if Index <= Text'Last
        and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (Index))
      then
         Digit := Text (Index);
         Width := 1;
         return True;
      end if;

      for Ch in Character range '0' .. '9' loop
         declare
            Localized : constant String := I18N.CLDR_Data.Digit_Text (Locale, Ch);
         begin
            if Localized /= String'(1 => Ch)
              and then Posix_Tools.Text.Matching.Starts_With_At (Text, Localized, Index)
            then
               Digit := Ch;
               Width := Localized'Length;
               return True;
            end if;
         end;
      end loop;

      Digit := '0';
      Width := 0;
      return False;
   end Locale_Digit_At;

   function Numeric_Field (Locale, Text : String) return String is
      Index             : Positive := Text'First;
      Output            : Unbounded_String;
      Decimal_Separator : constant String := I18N.CLDR_Data.Decimal_Separator (Locale);
      Plus_Sign         : constant String := I18N.CLDR_Data.Number_Plus_Sign (Locale);
      Minus_Sign        : constant String := I18N.CLDR_Data.Number_Minus_Sign (Locale);
      Has_Digit         : Boolean := False;
      Digit             : Character;
      Width             : Natural;

      function At_Decimal_Separator return Boolean;

      procedure Consume_Digits;

      procedure Consume_Sign;

      function At_Decimal_Separator return Boolean is
      begin
         return (Index <= Text'Last and then Text (Index) = '.')
           or else
             (Decimal_Separator /= "."
              and then Posix_Tools.Text.Matching.Starts_With_At
                (Text, Decimal_Separator, Index));
      end At_Decimal_Separator;

      procedure Consume_Digits is
      begin
         while Index <= Text'Last
           and then Locale_Digit_At (Locale, Text, Index, Digit, Width)
         loop
            Append (Output, Digit);
            Has_Digit := True;
            Index := Index + Width;
         end loop;
      end Consume_Digits;

      procedure Consume_Sign is
      begin
         if Index <= Text'Last and then Text (Index) in '-' | '+' then
            Append (Output, Text (Index));
            Index := Index + 1;
         elsif Minus_Sign /= "-"
           and then Posix_Tools.Text.Matching.Starts_With_At (Text, Minus_Sign, Index)
         then
            Append (Output, "-");
            Index := Index + Minus_Sign'Length;
         elsif Plus_Sign /= "+"
           and then Posix_Tools.Text.Matching.Starts_With_At (Text, Plus_Sign, Index)
         then
            Append (Output, "+");
            Index := Index + Plus_Sign'Length;
         end if;
      end Consume_Sign;
   begin
      while Index <= Text'Last
        and then Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (Index))
      loop
         Index := Index + 1;
      end loop;

      Consume_Sign;
      Consume_Digits;

      if At_Decimal_Separator then
         Append (Output, ".");
         Index :=
           Index
           + (if Index <= Text'Last and then Text (Index) = '.'
              then 1
              else Decimal_Separator'Length);
         Consume_Digits;
      end if;

      if not Has_Digit then
         return "0";
      end if;

      if Index <= Text'Last and then Text (Index) in 'e' | 'E' then
         declare
            Exponent_Start         : constant Positive := Index;
            Exponent_Output_Length : constant Natural := Length (Output);
            Exponent_Has_Digit     : Boolean := False;
         begin
            Append (Output, Text (Index));
            Index := Index + 1;
            Consume_Sign;
            while Index <= Text'Last
              and then Locale_Digit_At (Locale, Text, Index, Digit, Width)
            loop
               Append (Output, Digit);
               Exponent_Has_Digit := True;
               Index := Index + Width;
            end loop;

            if not Exponent_Has_Digit then
               declare
                  Previous : constant String := To_String (Output);
               begin
                  Output :=
                    To_Unbounded_String
                      (Previous (Previous'First .. Previous'First + Exponent_Output_Length - 1));
                  Index := Exponent_Start;
               end;
            end if;
         end;
      end if;

      return To_String (Output);
   end Numeric_Field;

   function Decimal_Compare (Left, Right : String) return Integer is
      function Normalized_Decimal (Value : String) return String;

      function Dot_Or_After (Value : String) return Natural;

      function Start_Of_Number (Value : String) return Positive;

      function Trimmed_Fraction (Value : String) return String;

      function Trimmed_Integer (Value : String) return String;

      function Normalized_Decimal (Value : String) return String is
         Sign_First        : constant Positive := Value'First;
         Digit_First       : Positive := Value'First;
         Dot               : Natural := 0;
         Exponent_Marker   : Natural := 0;
         Exponent_Negative : Boolean := False;
         Exponent          : Integer := 0;
         Numeric_Digits    : Unbounded_String;
      begin
         if Value (Digit_First) in '-' | '+' then
            Digit_First := Digit_First + 1;
         end if;

         for I in Digit_First .. Value'Last loop
            if Value (I) = '.' then
               Dot := I;
            elsif Value (I) in 'e' | 'E' then
               Exponent_Marker := I;
               exit;
            end if;
         end loop;

         if Exponent_Marker = 0 then
            return Value;
         end if;

         if Exponent_Marker < Value'Last then
            declare
               I : Positive := Exponent_Marker + 1;
            begin
               if Value (I) in '-' | '+' then
                  Exponent_Negative := Value (I) = '-';
                  I := I + 1;
               end if;

               while I <= Value'Last
                 and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Value (I))
               loop
                  if Exponent <= 1_000_000 then
                     Exponent :=
                       Exponent * 10
                       + Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Value (I));
                  end if;
                  I := I + 1;
               end loop;
            end;
         end if;

         if Exponent_Negative then
            Exponent := -Exponent;
         end if;

         for I in Digit_First .. Exponent_Marker - 1 loop
            if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Value (I)) then
               Append (Numeric_Digits, Value (I));
            end if;
         end loop;

         declare
            Raw_Digits : constant String := To_String (Numeric_Digits);
            Integer_Digits : constant Integer :=
              (if Dot = 0
               then Exponent_Marker - Digit_First
               else Dot - Digit_First);
            Decimal_Position : constant Integer := Integer_Digits + Exponent;
            Output : Unbounded_String;
         begin
            if Value (Sign_First) = '-' then
               Append (Output, "-");
            elsif Value (Sign_First) = '+' then
               Append (Output, "+");
            end if;

            if Decimal_Position <= 0 then
               Append (Output, "0.");
               for I in 1 .. Natural (-Decimal_Position) loop
                  Append (Output, "0");
               end loop;
               Append (Output, Raw_Digits);
            elsif Decimal_Position >= Raw_Digits'Length then
               Append (Output, Raw_Digits);
               for I in 1 .. Natural (Decimal_Position - Raw_Digits'Length) loop
                  Append (Output, "0");
               end loop;
            else
               Append (Output, Raw_Digits (Raw_Digits'First .. Raw_Digits'First + Decimal_Position - 1));
               Append (Output, ".");
               Append (Output, Raw_Digits (Raw_Digits'First + Decimal_Position .. Raw_Digits'Last));
            end if;

            return To_String (Output);
         end;
      end Normalized_Decimal;

      function Start_Of_Number (Value : String) return Positive is
      begin
         if Value (Value'First) in '-' | '+' then
            return Value'First + 1;
         else
            return Value'First;
         end if;
      end Start_Of_Number;

      function Dot_Or_After (Value : String) return Natural is
      begin
         for I in Start_Of_Number (Value) .. Value'Last loop
            if Value (I) = '.' then
               return I;
            end if;
         end loop;
         return Value'Last + 1;
      end Dot_Or_After;

      function Trimmed_Integer (Value : String) return String is
         First : Natural := Start_Of_Number (Value);
         Dot   : constant Natural := Dot_Or_After (Value);
      begin
         while First < Dot - 1 and then Value (First) = '0' loop
            First := First + 1;
         end loop;
         if First >= Dot then
            return "0";
         end if;
         return Value (First .. Dot - 1);
      end Trimmed_Integer;

      function Trimmed_Fraction (Value : String) return String is
         Dot  : constant Natural := Dot_Or_After (Value);
         Last : Natural := Value'Last;
      begin
         if Dot > Value'Last then
            return "";
         end if;
         while Last > Dot and then Value (Last) = '0' loop
            Last := Last - 1;
         end loop;
         if Last = Dot then
            return "";
         end if;
         return Value (Dot + 1 .. Last);
      end Trimmed_Fraction;

      Normal_Left    : constant String := Normalized_Decimal (Left);
      Normal_Right   : constant String := Normalized_Decimal (Right);
      Left_Negative  : constant Boolean := Normal_Left (Normal_Left'First) = '-';
      Right_Negative : constant Boolean := Normal_Right (Normal_Right'First) = '-';
      Left_Integer   : constant String := Trimmed_Integer (Normal_Left);
      Right_Integer  : constant String := Trimmed_Integer (Normal_Right);
      Left_Fraction  : constant String := Trimmed_Fraction (Normal_Left);
      Right_Fraction : constant String := Trimmed_Fraction (Normal_Right);
      Magnitude      : Integer := 0;
   begin
      if Left_Negative /= Right_Negative then
         return (if Left_Negative then -1 else 1);
      elsif Left_Integer'Length /= Right_Integer'Length then
         Magnitude := (if Left_Integer'Length > Right_Integer'Length then 1 else -1);
      elsif Left_Integer /= Right_Integer then
         Magnitude := (if Left_Integer > Right_Integer then 1 else -1);
      else
         declare
            Max        : constant Natural := Natural'Max (Left_Fraction'Length, Right_Fraction'Length);
            Left_Char  : Character;
            Right_Char : Character;
         begin
            if Max > 0 then
               for Offset in 0 .. Max - 1 loop
                  Left_Char :=
                    (if Offset < Left_Fraction'Length
                     then Left_Fraction (Left_Fraction'First + Offset)
                     else '0');
                  Right_Char :=
                    (if Offset < Right_Fraction'Length
                     then Right_Fraction (Right_Fraction'First + Offset)
                     else '0');
                  if Left_Char /= Right_Char then
                     Magnitude := (if Left_Char > Right_Char then 1 else -1);
                     exit;
                  end if;
               end loop;
            end if;
         end;
      end if;

      return (if Left_Negative then -Magnitude else Magnitude);
   end Decimal_Compare;

   function Numeric_Compare (Locale, Left, Right : String) return Integer is
   begin
      return Decimal_Compare (Numeric_Field (Locale, Left), Numeric_Field (Locale, Right));
   end Numeric_Compare;
end Posix_Tools.Text.Sort_Numeric;
