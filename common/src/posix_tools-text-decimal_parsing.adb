package body Posix_Tools.Text.Decimal_Parsing
  with SPARK_Mode => On
is
   function Safe_Product_Sum
     (Left   : Long_Long_Integer;
      Right  : Long_Long_Integer;
      Addend : Long_Long_Integer) return Long_Long_Integer
     with
       Pre =>
         Left >= 0
         and then Right > 0
         and then Addend >= 0
         and then Left <= (Long_Long_Integer'Last - Addend) / Right,
       Post => Safe_Product_Sum'Result >= 0;

   function Safe_Product_Sum
     (Left   : Long_Long_Integer;
      Right  : Long_Long_Integer;
      Addend : Long_Long_Integer) return Long_Long_Integer is
   begin
      return Left * Right + Addend;
   end Safe_Product_Sum;

   function Decimal_In_Range (Text : String; Low, High : Natural) return Boolean
   is
      Parsed : constant Parsed_Natural := Natural_Value (Text);
   begin
      return Parsed.Valid and then Parsed.Value in Low .. High;
   end Decimal_In_Range;

   function Decimal_Number (Text : String) return Parsed_Decimal_Number
   is
      Negative            : Boolean := False;
      Exponent_Negative   : Boolean := False;
      In_Exponent         : Boolean := False;
      Seen_Exponent       : Boolean := False;
      Seen_Digit          : Boolean := False;
      Seen_Exponent_Digit : Boolean := False;
      Seen_Dot            : Boolean := False;
      Acc                 : Long_Long_Integer;
      Whole_Value         : Long_Long_Integer := 0;
      Fraction_Value      : Long_Long_Integer := 0;
      Whole_First         : Natural := 0;
      Whole_Last          : Natural := 0;
      Fraction_First      : Natural := 0;
      Fraction_Last       : Natural := 0;
      Exponent            : Natural := 0;
      Exponent_First      : Natural := 0;
      Exponent_Last       : Natural := 0;
      Scale               : Natural := 0;
   begin
      if Text = "" then
         return (Valid => False, Mantissa => 0, Scale => 0);
      end if;

      for I in Text'Range loop
         pragma Loop_Invariant (Whole_First = 0 or else Whole_First in Text'First .. I);
         pragma Loop_Invariant (Whole_Last = 0 or else Whole_Last in Text'First .. I);
         pragma Loop_Invariant (Whole_First = 0 or else Whole_Last = 0 or else Whole_First <= Whole_Last);
         pragma Loop_Invariant (Fraction_First = 0 or else Fraction_First in Text'First .. I);
         pragma Loop_Invariant (Fraction_Last = 0 or else Fraction_Last in Text'First .. I);
         pragma Loop_Invariant
           (Fraction_First = 0 or else Fraction_Last = 0 or else Fraction_First <= Fraction_Last);
         pragma Loop_Invariant (Exponent_First = 0 or else Exponent_First in Text'First .. I);
         pragma Loop_Invariant (Exponent_Last = 0 or else Exponent_Last in Text'First .. I);
         pragma Loop_Invariant
           (Exponent_First = 0 or else Exponent_Last = 0 or else Exponent_First <= Exponent_Last);
         pragma Loop_Invariant
           (if Seen_Exponent_Digit then Exponent_First /= 0 and then Exponent_Last /= 0);

         if I = Text'First and then (Text (I) = '-' or else Text (I) = '+') then
            Negative := Text (I) = '-';
         elsif In_Exponent and then I > Text'First
           and then (Text (I - 1) = 'e' or else Text (I - 1) = 'E')
           and then (Text (I) = '-' or else Text (I) = '+')
         then
            Exponent_Negative := Text (I) = '-';
         elsif not In_Exponent and then (Text (I) = 'e' or else Text (I) = 'E') then
            if Seen_Exponent or else not Seen_Digit then
               return (Valid => False, Mantissa => 0, Scale => 0);
            end if;
            Seen_Exponent := True;
            In_Exponent := True;
         elsif Text (I) = '.' then
            if Seen_Dot or else In_Exponent then
               return (Valid => False, Mantissa => 0, Scale => 0);
            end if;
            Seen_Dot := True;
         elsif Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I)) then
            if In_Exponent then
               Seen_Exponent_Digit := True;
               if Exponent_First = 0 then
                  Exponent_First := I;
               end if;
               Exponent_Last := I;
            else
               Seen_Digit := True;
               if Seen_Dot then
                  if Fraction_First = 0 then
                     Fraction_First := I;
                  end if;
                  Fraction_Last := I;
                  if Scale = Natural'Last then
                     return (Valid => False, Mantissa => 0, Scale => 0);
                  end if;
                  Scale := Scale + 1;
               else
                  if Whole_First = 0 then
                     Whole_First := I;
                  end if;
                  Whole_Last := I;
               end if;
            end if;
         else
            return (Valid => False, Mantissa => 0, Scale => 0);
         end if;
      end loop;

      if not Seen_Digit then
         return (Valid => False, Mantissa => 0, Scale => 0);
      elsif Seen_Exponent and then not Seen_Exponent_Digit then
         return (Valid => False, Mantissa => 0, Scale => 0);
      end if;

      if Whole_First /= 0 then
         declare
            Parsed_Whole : constant Parsed_Long_Long :=
              Long_Long_Value (Text (Whole_First .. Whole_Last));
         begin
            if not Parsed_Whole.Valid or else Parsed_Whole.Value < 0 then
               return (Valid => False, Mantissa => 0, Scale => 0);
            end if;
            Whole_Value := Parsed_Whole.Value;
         end;
      end if;

      if Fraction_First /= 0 then
         declare
            Parsed_Fraction : constant Parsed_Long_Long :=
              Long_Long_Value (Text (Fraction_First .. Fraction_Last));
         begin
            if not Parsed_Fraction.Valid or else Parsed_Fraction.Value < 0 then
               return (Valid => False, Mantissa => 0, Scale => 0);
            end if;
            Fraction_Value := Parsed_Fraction.Value;
         end;
      end if;

      declare
         Factor : constant Long_Long_Integer := Power_10 (Scale);
      begin
         if Factor = 0
           or else Whole_Value > (Long_Long_Integer'Last - Fraction_Value) / Factor
         then
            return (Valid => False, Mantissa => 0, Scale => 0);
         end if;
         pragma Assert (Whole_Value >= 0);
         pragma Assert (Fraction_Value >= 0);
         pragma Assert (Factor > 0);
         pragma Assert (Whole_Value <= (Long_Long_Integer'Last - Fraction_Value) / Factor);
         Acc := Safe_Product_Sum (Whole_Value, Factor, Fraction_Value);
      end;

      if Seen_Exponent_Digit then
         pragma Assert (Exponent_First in Text'Range);
         pragma Assert (Exponent_Last in Text'Range);
         pragma Assert (Exponent_First <= Exponent_Last);
         declare
            Parsed_Exponent : constant Parsed_Natural :=
              Natural_In_Range (Text (Exponent_First .. Exponent_Last), 0, 10_000_009);
         begin
            if not Parsed_Exponent.Valid then
               return (Valid => False, Mantissa => 0, Scale => 0);
            end if;
            Exponent := Parsed_Exponent.Value;
         end;
      end if;

      if Exponent_Negative then
         if Exponent > Natural'Last - Scale then
            return (Valid => False, Mantissa => 0, Scale => 0);
         end if;
         Scale := Scale + Exponent;
      elsif Exponent >= Scale then
         declare
            Scaled : constant Parsed_Long_Long := Scale_By_Power_10 (Acc, Exponent - Scale);
         begin
            if not Scaled.Valid then
               return (Valid => False, Mantissa => 0, Scale => 0);
            elsif Scaled.Value < 0 then
               return (Valid => False, Mantissa => 0, Scale => 0);
            end if;
            pragma Assert (Scaled.Value >= 0);
            Acc := Scaled.Value;
            Scale := 0;
         end;
      else
         Scale := Scale - Exponent;
      end if;

      pragma Assert (Acc >= 0);
      return (Valid => True, Mantissa => (if Negative then -Acc else Acc), Scale => Scale);
   end Decimal_Number;

   function Four_Digit_Value (Text : String) return Natural is
      Thousands : constant Natural :=
        Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Text (Text'First));
      Hundreds  : constant Natural :=
        Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Text (Text'First + 1));
      Tens      : constant Natural :=
        Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Text (Text'First + 2));
      Ones      : constant Natural :=
        Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Text (Text'First + 3));
   begin
      return Thousands * 1_000 + Hundreds * 100 + Tens * 10 + Ones;
   end Four_Digit_Value;

   function Long_Long_Value (Text : String) return Parsed_Long_Long
   is
      Acc       : Long_Long_Integer := 0;
      Negative  : Boolean := False;
      Processed : Natural := 0;
   begin
      if Text = "" then
         return (Valid => False, Value => 0);
      end if;

      if Text (Text'First) = '-' or else Text (Text'First) = '+' then
         Negative := Text (Text'First) = '-';
         Processed := 1;
      end if;

      if Processed = Text'Length then
         return (Valid => False, Value => 0);
      end if;

      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Acc >= 0);
         pragma Loop_Variant (Increases => Processed);

         declare
            Ch    : constant Character := Text (Text'First + Processed);
            Digit : Long_Long_Integer;
         begin
            if not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Ch) then
               return (Valid => False, Value => 0);
            end if;

            Digit :=
              Long_Long_Integer (Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Ch));
            if Acc > (Long_Long_Integer'Last - Digit) / 10 then
               return (Valid => False, Value => 0);
            end if;

            Acc := Acc * 10 + Digit;
         end;

         Processed := Processed + 1;
      end loop;

      return (Valid => True, Value => (if Negative then -Acc else Acc));
   end Long_Long_Value;

   function Natural_Field (Text : String; First : Positive) return Parsed_Natural_Field
   is
      Processed : Natural := First - Text'First;
      Value     : Natural := 0;
      Last      : Natural := 0;
      Seen      : Boolean := False;
   begin
      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Invariant (Last = 0 or else Last in Text'Range);
         pragma Loop_Invariant (if Seen then Last /= 0);
         pragma Loop_Variant (Increases => Processed);

         declare
            Index : constant Positive := Text'First + Processed;
            Ch    : constant Character := Text (Index);
            Digit : Natural;
         begin
            exit when not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Ch);

            Digit := Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Ch);
            if Value > (Natural'Last - Digit) / 10 then
               return (Valid => False, Value => 0, Last => 0, Next => 0, At_End => False);
            end if;

            Value := Value * 10 + Digit;
            Last := Index;
            Seen := True;
         end;

         Processed := Processed + 1;
      end loop;

      if not Seen then
         return (Valid => False, Value => 0, Last => 0, Next => 0, At_End => False);
      elsif Processed = Text'Length then
         return (Valid => True, Value => Value, Last => Last, Next => 0, At_End => True);
      else
         return
           (Valid  => True,
            Value  => Value,
            Last   => Last,
            Next   => Text'First + Processed,
            At_End => False);
      end if;
   end Natural_Field;

   function Natural_In_Range (Text : String; Low, High : Natural) return Parsed_Natural
   is
      Parsed : constant Parsed_Natural := Natural_Value (Text);
   begin
      if Parsed.Valid and then Parsed.Value in Low .. High then
         return Parsed;
      else
         return (Valid => False, Value => 0);
      end if;
   end Natural_In_Range;

   function Natural_Value (Text : String) return Parsed_Natural
   is
      Acc       : Natural := 0;
      Processed : Natural := 0;
   begin
      if Text = "" then
         return (Valid => False, Value => 0);
      end if;

      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Variant (Increases => Processed);

         declare
            Ch    : constant Character := Text (Text'First + Processed);
            Digit : Natural;
         begin
            if not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Ch) then
               return (Valid => False, Value => 0);
            end if;

            Digit := Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Ch);
            if Acc > (Natural'Last - Digit) / 10 then
               return (Valid => False, Value => 0);
            end if;

            Acc := Acc * 10 + Digit;
         end;

         Processed := Processed + 1;
      end loop;

      return (Valid => True, Value => Acc);
   end Natural_Value;

   function Power_10 (Count : Natural) return Long_Long_Integer
   is
      Result    : Long_Long_Integer := 1;
      Processed : Natural := 0;
   begin
      while Processed < Count loop
         pragma Loop_Invariant (Processed <= Count);
         pragma Loop_Invariant (Result >= 1);
         pragma Loop_Variant (Increases => Processed);

         if Result > Long_Long_Integer'Last / 10 then
            return 0;
         end if;

         Result := Result * 10;
         Processed := Processed + 1;
      end loop;

      return Result;
   end Power_10;

   function Scale_By_Power_10
     (Value : Long_Long_Integer;
      Count : Natural) return Parsed_Long_Long
   is
      Acc       : Long_Long_Integer;
      Negative  : constant Boolean := Value < 0;
      Processed : Natural := 0;
   begin
      if Value = Long_Long_Integer'First then
         return (Valid => False, Value => 0);
      elsif Negative then
         Acc := -Value;
      else
         Acc := Value;
      end if;

      while Processed < Count loop
         pragma Loop_Invariant (Processed <= Count);
         pragma Loop_Invariant (Acc >= 0);
         pragma Loop_Variant (Increases => Processed);

         if Acc > Long_Long_Integer'Last / 10 then
            return (Valid => False, Value => 0);
         end if;

         Acc := Acc * 10;
         Processed := Processed + 1;
      end loop;

      return (Valid => True, Value => (if Negative then -Acc else Acc));
   end Scale_By_Power_10;

   function Scale_Decimal_Number
     (Item : Parsed_Decimal_Number;
      Target_Scale : Natural) return Parsed_Long_Long is
   begin
      return Scale_By_Power_10 (Item.Mantissa, Target_Scale - Item.Scale);
   end Scale_Decimal_Number;

   function Two_Digit_Value (Text : String) return Natural is
      Tens : constant Natural :=
        Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Text (Text'First));
      Ones : constant Natural :=
        Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Text (Text'Last));
   begin
      return Tens * 10 + Ones;
   end Two_Digit_Value;
end Posix_Tools.Text.Decimal_Parsing;
