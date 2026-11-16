with Ada.Strings.Unbounded;
with Ada.Numerics.Big_Numbers.Big_Integers;
with I18N.Number_Format;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Matching;

package body Posix_Tools.Text.Sort_Numeric is
   use Ada.Strings.Unbounded;
   package Big_Integers renames Ada.Numerics.Big_Numbers.Big_Integers;
   use type Big_Integers.Big_Integer;

   type Decimal_Value is record
      Negative    : Boolean := False;
      Zero        : Boolean := True;
      Order       : Big_Integers.Big_Integer :=
        Big_Integers.To_Big_Integer (0);
      Significant : Unbounded_String;
   end record;

   function Big_Image (Value : Big_Integers.Big_Integer) return String;

   function Parse_Decimal (Value : String) return Decimal_Value;

   function Big_Image (Value : Big_Integers.Big_Integer) return String is
      Image : constant String := Big_Integers.To_String (Value);
   begin
      return
        (if Image (Image'First) = ' '
         then Image (Image'First + 1 .. Image'Last)
         else Image);
   end Big_Image;

   function Parse_Decimal (Value : String) return Decimal_Value is
      Result              : Decimal_Value;
      Number_First        : Natural := Value'First;
      Dot                 : Natural := 0;
      Exponent_Marker     : Natural := 0;
      Integer_Digit_Count : Natural := 0;
      Raw                 : Unbounded_String;
      Exponent            : Big_Integers.Big_Integer :=
        Big_Integers.To_Big_Integer (0);
   begin
      if Value'Length = 0 then
         return Result;
      end if;

      Result.Negative := Value (Number_First) = '-';
      if Value (Number_First) in '-' | '+' then
         Number_First := Number_First + 1;
      end if;

      for I in Number_First .. Value'Last loop
         if Value (I) = '.' then
            Dot := I;
         elsif Value (I) in 'e' | 'E' then
            Exponent_Marker := I;
            exit;
         end if;
      end loop;

      declare
         Mantissa_Last : constant Natural :=
           (if Exponent_Marker = 0 then Value'Last else Exponent_Marker - 1);
         Decimal_Point : constant Natural :=
           (if Dot = 0 then Mantissa_Last + 1 else Dot);
      begin
         Integer_Digit_Count := Decimal_Point - Number_First;
         for I in Number_First .. Mantissa_Last loop
            if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Value (I)) then
               Append (Raw, Value (I));
            end if;
         end loop;
      end;

      if Exponent_Marker /= 0 and then Exponent_Marker < Value'Last then
         declare
            First : constant Positive := Exponent_Marker + 1;
            Last : Natural := First - 1;
            I : Natural := First;
            Has_Digit : Boolean := False;
         begin
            if Value (I) in '-' | '+' then
               I := I + 1;
            end if;
            while I <= Value'Last
              and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Value (I))
            loop
               Last := I;
               Has_Digit := True;
               I := I + 1;
            end loop;
            if Has_Digit then
               Exponent := Big_Integers.From_String (Value (First .. Last));
            end if;
         end;
      end if;

      declare
         Raw_Digits : constant String := To_String (Raw);
         First      : Natural := Raw_Digits'First;
         Last       : Natural := Raw_Digits'Last;
      begin
         while First <= Last and then Raw_Digits (First) = '0' loop
            First := First + 1;
         end loop;
         if First > Last then
            Result.Negative := False;
            return Result;
         end if;
         while Last > First and then Raw_Digits (Last) = '0' loop
            Last := Last - 1;
         end loop;

         Result.Zero := False;
         Result.Significant := To_Unbounded_String (Raw_Digits (First .. Last));
         Result.Order :=
           Exponent
           + Big_Integers.To_Big_Integer (Integer (Integer_Digit_Count))
           - Big_Integers.To_Big_Integer (Integer (First - Raw_Digits'First))
           - Big_Integers.To_Big_Integer (1);
         return Result;
      end;
   end Parse_Decimal;

   function Locale_Digit_At
     (Locale : String;
      Text   : String;
      Index  : Positive;
      Limit  : Natural;
      ASCII_Format : Boolean;
      Digit  : out Character;
      Width  : out Natural) return Boolean;

   function Locale_Digit_At
     (Locale : String;
      Text   : String;
      Index  : Positive;
      Limit  : Natural;
      ASCII_Format : Boolean;
      Digit  : out Character;
      Width  : out Natural) return Boolean
   is
   begin
      if Index <= Limit
        and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (Index))
      then
         Digit := Text (Index);
         Width := 1;
         return True;
      end if;

      if ASCII_Format then
         Digit := '0';
         Width := 0;
         return False;
      end if;

      for Ch in Character range '0' .. '9' loop
         declare
            Localized : constant String := I18N.Number_Format.Digit_Text (Locale, Ch);
         begin
            if Localized /= String'(1 => Ch)
              and then Localized'Length <= Limit - Index + 1
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
   begin
      return Numeric_Field (Locale, Text, Text'First, Text'Last, ASCII_Format => False);
   end Numeric_Field;

   function Numeric_Field
     (Locale : String;
      Text   : String;
      First  : Positive;
      Last   : Natural;
      ASCII_Format : Boolean := False) return String
   is
      Index             : Positive := First;
      Output            : Unbounded_String;
      Decimal_Separator : constant String :=
        (if ASCII_Format then "." else I18N.Number_Format.Decimal_Separator (Locale));
      Plus_Sign         : constant String :=
        (if ASCII_Format then "+" else I18N.Number_Format.Plus_Sign (Locale));
      Minus_Sign        : constant String :=
        (if ASCII_Format then "-" else I18N.Number_Format.Minus_Sign (Locale));
      Has_Digit         : Boolean := False;
      Digit             : Character;
      Width             : Natural;

      function At_Decimal_Separator return Boolean;

      procedure Consume_Digits;

      procedure Consume_Sign;

      function At_Decimal_Separator return Boolean is
      begin
         return (Index <= Last and then Text (Index) = '.')
           or else
             (Index <= Last
              and then Decimal_Separator /= "."
              and then Decimal_Separator'Length <= Last - Index + 1
              and then Posix_Tools.Text.Matching.Starts_With_At
                (Text, Decimal_Separator, Index));
      end At_Decimal_Separator;

      procedure Consume_Digits is
      begin
         while Index <= Last
           and then Locale_Digit_At
             (Locale, Text, Index, Last, ASCII_Format, Digit, Width)
         loop
            Append (Output, Digit);
            Has_Digit := True;
            Index := Index + Width;
         end loop;
      end Consume_Digits;

      procedure Consume_Sign is
      begin
         if Index <= Last and then Text (Index) in '-' | '+' then
            Append (Output, Text (Index));
            Index := Index + 1;
         elsif Minus_Sign /= "-"
           and then Index <= Last
           and then Minus_Sign'Length <= Last - Index + 1
           and then Posix_Tools.Text.Matching.Starts_With_At (Text, Minus_Sign, Index)
         then
            Append (Output, "-");
            Index := Index + Minus_Sign'Length;
         elsif Plus_Sign /= "+"
           and then Index <= Last
           and then Plus_Sign'Length <= Last - Index + 1
           and then Posix_Tools.Text.Matching.Starts_With_At (Text, Plus_Sign, Index)
         then
            Append (Output, "+");
            Index := Index + Plus_Sign'Length;
         end if;
      end Consume_Sign;
   begin
      while Index <= Last
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
           + (if Index <= Last and then Text (Index) = '.'
              then 1
              else Decimal_Separator'Length);
         Consume_Digits;
      end if;

      if not Has_Digit then
         return "0";
      end if;

      if Index <= Last and then Text (Index) in 'e' | 'E' then
         declare
            Exponent_Start         : constant Positive := Index;
            Exponent_Output_Length : constant Natural := Length (Output);
            Exponent_Has_Digit     : Boolean := False;
         begin
            Append (Output, Text (Index));
            Index := Index + 1;
            Consume_Sign;
            while Index <= Last
              and then Locale_Digit_At
                (Locale, Text, Index, Last, ASCII_Format, Digit, Width)
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

   function Canonical_Decimal (Value : String) return String is
      Parsed : constant Decimal_Value := Parse_Decimal (Value);
   begin
      if Parsed.Zero then
         return "0";
      end if;

      declare
         Significant     : constant String := To_String (Parsed.Significant);
         Sign_Length     : constant Natural := Boolean'Pos (Parsed.Negative);
         Expansion_Limit : constant Big_Integers.Big_Integer :=
           Big_Integers.To_Big_Integer (Integer (Value'Length))
           * Big_Integers.To_Big_Integer (4)
           + Big_Integers.To_Big_Integer (32);
         Plain_Length    : Big_Integers.Big_Integer;
         Output          : Unbounded_String;
      begin
         if Parsed.Order < Big_Integers.To_Big_Integer (0) then
            Plain_Length :=
              Big_Integers.To_Big_Integer
                (Sign_Length + 2 + Significant'Length)
              - Parsed.Order - Big_Integers.To_Big_Integer (1);
         elsif Parsed.Order + Big_Integers.To_Big_Integer (1)
           >= Big_Integers.To_Big_Integer (Significant'Length)
         then
            Plain_Length :=
              Big_Integers.To_Big_Integer (Sign_Length) + Parsed.Order
              + Big_Integers.To_Big_Integer (1);
         else
            Plain_Length :=
              Big_Integers.To_Big_Integer
                (Sign_Length + Significant'Length + 1);
         end if;

         if Parsed.Negative then
            Append (Output, "-");
         end if;

         if Plain_Length <= Expansion_Limit
           and then Big_Integers.In_Range
             (Parsed.Order,
              Big_Integers.To_Big_Integer (Integer'First),
              Big_Integers.To_Big_Integer (Integer'Last))
         then
            declare
               Order : constant Integer := Big_Integers.To_Integer (Parsed.Order);
            begin
               if Order < 0 then
                  Append (Output, "0.");
                  Append (Output, String'(1 .. -Order - 1 => '0'));
                  Append (Output, Significant);
               elsif Order + 1 >= Significant'Length then
                  Append (Output, Significant);
                  Append
                    (Output,
                     String'
                       (1 .. Order + 1 - Significant'Length => '0'));
               else
                  Append
                    (Output,
                     Significant
                       (Significant'First .. Significant'First + Order));
                  Append (Output, ".");
                  Append
                    (Output,
                     Significant
                       (Significant'First + Order + 1 .. Significant'Last));
               end if;
            end;
         else
            Append (Output, Significant (Significant'First));
            if Significant'Length > 1 then
               Append (Output, ".");
               Append
                 (Output,
                  Significant (Significant'First + 1 .. Significant'Last));
            end if;
            Append (Output, "e");
            Append (Output, Big_Image (Parsed.Order));
         end if;
         return To_String (Output);
      end;
   end Canonical_Decimal;

   function Decimal_Sort_Key (Value : String) return String is
      Parsed : constant Decimal_Value := Parse_Decimal (Value);
      Output : Unbounded_String;

      procedure Append_Complemented (Text : String);

      procedure Append_Complemented (Text : String) is
      begin
         for Digit of Text loop
            Append
              (Output,
               Character'Val
                 (Character'Pos ('9')
                  - (Character'Pos (Digit) - Character'Pos ('0'))));
         end loop;
      end Append_Complemented;

      function Encoded_Order return String is
         Image  : constant String := Big_Image (Parsed.Order);
         Result : Unbounded_String;
      begin
         if Parsed.Order < Big_Integers.To_Big_Integer (0) then
            declare
               Magnitude : constant String := Image (Image'First + 1 .. Image'Last);
            begin
               Append (Result, "0");
               Append (Result, String'(1 .. Magnitude'Length => '0'));
               Append (Result, "1");
               for Digit of Magnitude loop
                  Append
                    (Result,
                     Character'Val
                       (Character'Pos ('9')
                        - (Character'Pos (Digit) - Character'Pos ('0'))));
               end loop;
            end;
         elsif Parsed.Order = Big_Integers.To_Big_Integer (0) then
            Append (Result, "1");
         else
            Append (Result, "2");
            Append (Result, String'(1 .. Image'Length => '1'));
            Append (Result, "0");
            Append (Result, Image);
         end if;
         return To_String (Result);
      end Encoded_Order;
   begin
      if Parsed.Zero then
         return "1";
      end if;

      if Parsed.Negative then
         Append (Output, "0");
         Append_Complemented (Encoded_Order);
         Append_Complemented (To_String (Parsed.Significant));
         Append (Output, ":");
      else
         Append (Output, "2");
         Append (Output, Encoded_Order);
         Append (Output, Parsed.Significant);
         Append (Output, "/");
      end if;
      return To_String (Output);
   end Decimal_Sort_Key;

   function Decimal_Compare
     (Left, Right : String;
      Canonical   : Boolean := False) return Integer
   is
      pragma Unreferenced (Canonical);
      Left_Value       : constant Decimal_Value := Parse_Decimal (Left);
      Right_Value      : constant Decimal_Value := Parse_Decimal (Right);
      Left_Significant : constant String :=
        To_String (Left_Value.Significant);
      Right_Significant : constant String :=
        To_String (Right_Value.Significant);
      Magnitude : Integer := 0;
   begin
      if Left_Value.Zero and then Right_Value.Zero then
         return 0;
      elsif Left_Value.Negative /= Right_Value.Negative then
         return (if Left_Value.Negative then -1 else 1);
      elsif Left_Value.Order /= Right_Value.Order then
         Magnitude := (if Left_Value.Order < Right_Value.Order then -1 else 1);
      elsif Left_Significant /= Right_Significant then
         Magnitude :=
           (if Left_Significant < Right_Significant then -1 else 1);
      end if;
      return (if Left_Value.Negative then -Magnitude else Magnitude);
   end Decimal_Compare;

   function Numeric_Compare (Locale, Left, Right : String) return Integer is
   begin
      return Decimal_Compare (Numeric_Field (Locale, Left), Numeric_Field (Locale, Right));
   end Numeric_Compare;
end Posix_Tools.Text.Sort_Numeric;
