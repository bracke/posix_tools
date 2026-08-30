with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Text.Sort_Modifiers
  with SPARK_Mode => On
is
   function Invalid_Key return Parsed_Key
     with
       Post =>
         not Invalid_Key'Result.Valid
         and then Invalid_Key'Result.Field_Start = 1
         and then Invalid_Key'Result.Field_End = 0
         and then Invalid_Key'Result.Character_Start = 1
         and then Invalid_Key'Result.Character_End = 0;

   function Applies_Locale_Collation
     (Fold_Case, Dictionary_Order, Ignore_Nonprinting : Boolean) return Boolean is
   begin
      return not (Fold_Case or else Dictionary_Order or else Ignore_Nonprinting);
   end Applies_Locale_Collation;

   function Invalid_Key return Parsed_Key is
   begin
      return (others => <>);
   end Invalid_Key;

   function Is_Key_Modifier (Ch : Character) return Boolean is
   begin
      return Ch in 'b' | 'd' | 'f' | 'i' | 'n' | 'r';
   end Is_Key_Modifier;

   function Parse_Key (Text : String) return Parsed_Key is
      Last : Natural;
      End_Last : Natural;
      Parsed_Number : Parsed_Key_Number;
      Value : Natural;
      Field      : Positive;
      End_Field  : Natural := 0;
      Char_Start : Positive := 1;
      End_Char   : Natural := 0;
      Key_Dictionary_Order : Boolean := False;
      Key_Fold_Case : Boolean := False;
      Key_Ignore_Leading_Blanks : Boolean := False;
      Key_Ignore_Nonprinting : Boolean := False;
      Key_Numeric_Sort : Boolean := False;
      Key_Reverse_Order : Boolean := False;

      procedure Note_Key_Modifier (Ch : Character);

      procedure Parse_Key_Modifiers;

      procedure Note_Key_Modifier (Ch : Character) is
      begin
         if Ch = 'b' then
            Key_Ignore_Leading_Blanks := True;
         elsif Ch = 'd' then
            Key_Dictionary_Order := True;
         elsif Ch = 'f' then
            Key_Fold_Case := True;
         elsif Ch = 'i' then
            Key_Ignore_Nonprinting := True;
         elsif Ch = 'n' then
            Key_Numeric_Sort := True;
         elsif Ch = 'r' then
            Key_Reverse_Order := True;
         end if;
      end Note_Key_Modifier;

      procedure Parse_Key_Modifiers is
      begin
         while Last < Text'Last and then Is_Key_Modifier (Text (Last + 1)) loop
            pragma Loop_Invariant (Last in Text'First - 1 .. Text'Last - 1);
            pragma Loop_Variant (Increases => Last);

            Last := Last + 1;
            Note_Key_Modifier (Text (Last));
         end loop;
      end Parse_Key_Modifiers;
   begin
      if Text = "" then
         return Invalid_Key;
      end if;

      Parsed_Number := Parse_Positive_Key_Number (Text, Text'First, Text'Last);
      if not Parsed_Number.Valid then
         return Invalid_Key;
      end if;

      Field := Positive (Parsed_Number.Value);
      Last := Parsed_Number.Last_Digit;

      if Last < Text'Last and then Text (Last + 1) = '.' then
         Parsed_Number := Parse_Positive_Key_Number (Text, Last + 2, Text'Last);
         if not Parsed_Number.Valid then
            return Invalid_Key;
         end if;
         Char_Start := Positive (Parsed_Number.Value);
         Last := Parsed_Number.Last_Digit;
      end if;

      Parse_Key_Modifiers;

      if Last < Text'Last and then Text (Last + 1) /= ',' then
         return Invalid_Key;
      end if;

      if Last < Text'Last then
         Parsed_Number := Parse_Positive_Key_Number (Text, Last + 2, Text'Last);
         if not Parsed_Number.Valid then
            return Invalid_Key;
         end if;

         Value := Parsed_Number.Value;
         End_Last := Parsed_Number.Last_Digit;
         End_Field := Value;

         if End_Last < Text'Last and then Text (End_Last + 1) = '.' then
            Parsed_Number := Parse_Positive_Key_Number (Text, End_Last + 2, Text'Last);
            if not Parsed_Number.Valid then
               return Invalid_Key;
            end if;

            Value := Parsed_Number.Value;
            End_Last := Parsed_Number.Last_Digit;
            End_Char := Value;
         end if;

         Last := End_Last;
         Parse_Key_Modifiers;
         if Last /= Text'Last
           or else End_Field < Field
           or else (End_Field = Field and then End_Char > 0 and then End_Char < Char_Start)
         then
            return Invalid_Key;
         end if;
      end if;

      return
        (Valid => True,
         Field_Start => Field,
         Field_End => End_Field,
         Character_Start => Char_Start,
         Character_End => End_Char,
         Fold_Case => Key_Fold_Case,
         Numeric_Sort => Key_Numeric_Sort,
         Ignore_Leading_Blanks => Key_Ignore_Leading_Blanks,
         Dictionary_Order => Key_Dictionary_Order,
         Ignore_Nonprinting => Key_Ignore_Nonprinting,
         Reverse_Order => Key_Reverse_Order);
   end Parse_Key;

   function Parse_Positive_Key_Number
     (Text  : String;
      Start : Positive;
      Stop  : Natural) return Parsed_Key_Number
   is
      Last_Digit : Natural := Start - 1;
   begin
      if Start > Stop then
         return (Valid => False, Value => 0, Last_Digit => Last_Digit);
      end if;

      while Last_Digit < Stop loop
         pragma Loop_Invariant (Last_Digit in Start - 1 .. Stop);
         pragma Loop_Invariant (Last_Digit < Start or else Last_Digit in Text'Range);
         pragma Loop_Invariant
           (if Last_Digit >= Start then
              (for all I in Start .. Last_Digit =>
                 Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I))));
         pragma Loop_Variant (Increases => Last_Digit);

         declare
            Next : constant Positive := Last_Digit + 1;
         begin
            pragma Assert (Next in Text'Range);
            if not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (Next)) then
               exit;
            end if;
            Last_Digit := Next;
         end;
      end loop;

      if Last_Digit < Start then
         return (Valid => False, Value => 0, Last_Digit => Last_Digit);
      end if;

      declare
         pragma Assert (Start in Text'Range);
         pragma Assert (Last_Digit in Text'Range);
         pragma Assert (Start <= Last_Digit);
         Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
           Posix_Tools.Text.Decimal_Parsing.Natural_Value (Text (Start .. Last_Digit));
      begin
         if Parsed.Valid and then Parsed.Value > 0 then
            return (Valid => True, Value => Parsed.Value, Last_Digit => Last_Digit);
         else
            return (Valid => False, Value => 0, Last_Digit => Last_Digit);
         end if;
      end;
   end Parse_Positive_Key_Number;
end Posix_Tools.Text.Sort_Modifiers;
