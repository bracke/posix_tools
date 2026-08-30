with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Text.Duration_Fields
  with SPARK_Mode => On
is
   function Invalid_Field return Parsed_Duration_Field;

   function Invalid_Milliseconds return Parsed_Duration_Milliseconds
     with
       Post =>
         not Invalid_Milliseconds'Result.Valid
         and then Invalid_Milliseconds'Result.Value = 0;

   function Invalid_Seconds return Parsed_Duration_Seconds
     with
       SPARK_Mode => Off;

   function Invalid_Field return Parsed_Duration_Field is
   begin
      return (Valid => False, Last_Index => 0, Dot_Index => 0, Unit => Seconds);
   end Invalid_Field;

   function Invalid_Milliseconds return Parsed_Duration_Milliseconds is
   begin
      return (Valid => False, Value => 0);
   end Invalid_Milliseconds;

   function Invalid_Seconds return Parsed_Duration_Seconds
     with SPARK_Mode => Off
   is
   begin
      return (Valid => False, Value => 0.0);
   end Invalid_Seconds;

   function Milliseconds_Multiplier_For (Unit : Duration_Unit) return Long_Long_Integer is
     (case Unit is
        when Seconds => 1_000,
        when Minutes => 60_000,
        when Hours   => 3_600_000,
        when Days    => 86_400_000);

   function Seconds_Multiplier_For (Unit : Duration_Unit) return Long_Long_Float is
     (case Unit is
        when Seconds => 1.0,
        when Minutes => 60.0,
        when Hours   => 3_600.0,
        when Days    => 86_400.0);

   function Parse_Field (Text : String) return Parsed_Duration_Field is
      Last_Index : Natural;
      Dot_Index  : Natural := 0;
      Unit       : Duration_Unit := Seconds;
      Seen_Digit : Boolean := False;
   begin
      if Text = "" or else Text (Text'First) = '-' then
         return Invalid_Field;
      end if;

      Last_Index := Text'Last;

      case Text (Text'Last) is
         when 's' =>
            Unit := Seconds;
         when 'm' =>
            Unit := Minutes;
         when 'h' =>
            Unit := Hours;
         when 'd' =>
            Unit := Days;
         when others =>
            null;
      end case;

      if Text (Text'Last) in 's' | 'm' | 'h' | 'd' then
         if Text'Last = Text'First then
            return Invalid_Field;
         end if;
         Last_Index := Text'Last - 1;
      end if;

      for I in Text'First .. Last_Index loop
         pragma Loop_Invariant (Dot_Index = 0 or else Dot_Index in Text'First .. I);

         if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I)) then
            Seen_Digit := True;
         elsif Text (I) = '.' and then Dot_Index = 0 then
            Dot_Index := I;
         else
            return Invalid_Field;
         end if;
      end loop;

      if Seen_Digit then
         return
           (Valid => True,
            Last_Index => Last_Index,
            Dot_Index => Dot_Index,
            Unit => Unit);
      else
         return Invalid_Field;
      end if;
   end Parse_Field;

   function Parse_Milliseconds (Text : String) return Parsed_Duration_Milliseconds is
      Parsed_Field : constant Parsed_Duration_Field := Parse_Field (Text);
      Parsed       : Posix_Tools.Text.Decimal_Parsing.Parsed_Decimal_Number;
      Denominator  : Long_Long_Integer;
      Multiplier   : Long_Long_Integer;
      Product      : Long_Long_Integer;
   begin
      if not Parsed_Field.Valid then
         return Invalid_Milliseconds;
      end if;

      Parsed :=
        Posix_Tools.Text.Decimal_Parsing.Decimal_Number
          (Text (Text'First .. Parsed_Field.Last_Index));
      if not Parsed.Valid or else Parsed.Mantissa < 0 then
         return Invalid_Milliseconds;
      end if;

      Denominator := Posix_Tools.Text.Decimal_Parsing.Power_10 (Parsed.Scale);
      Multiplier := Milliseconds_Multiplier_For (Parsed_Field.Unit);
      if Denominator = 0
        or else Parsed.Mantissa > Long_Long_Integer'Last / Multiplier
      then
         return Invalid_Milliseconds;
      end if;

      Product := Parsed.Mantissa * Multiplier;
      pragma Assert (Product >= 0);
      pragma Assert (Denominator >= 1);

      declare
         Quotient  : constant Long_Long_Integer := Product / Denominator;
         Remainder : constant Long_Long_Integer := Product rem Denominator;
         Round_Up_Threshold : constant Long_Long_Integer :=
           Denominator / 2 + Denominator rem 2;
      begin
         pragma Assert (Quotient >= 0);
         pragma Assert (Remainder >= 0);
         if Quotient > Long_Long_Integer (Natural'Last) then
            return Invalid_Milliseconds;
         elsif Remainder >= Round_Up_Threshold then
            if Quotient = Long_Long_Integer (Natural'Last) then
               return Invalid_Milliseconds;
            else
               return (Valid => True, Value => Natural (Quotient + 1));
            end if;
         else
            return (Valid => True, Value => Natural (Quotient));
         end if;
      end;
   end Parse_Milliseconds;

   function Parse_Seconds
     (Text        : String;
      Max_Seconds : Long_Long_Float) return Parsed_Duration_Seconds
     with SPARK_Mode => Off
   is
      Parsed_Field : constant Parsed_Duration_Field := Parse_Field (Text);
      Whole        : Long_Long_Integer := 0;
      Fraction     : Long_Long_Float := 0.0;
      Scale        : Long_Long_Float := 1.0;
      Value        : Long_Long_Float;
   begin
      if not Parsed_Field.Valid then
         return Invalid_Seconds;
      end if;

      for I in Text'First .. Parsed_Field.Last_Index loop
         declare
            Ch : constant Character := Text (I);
         begin
            if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Ch) then
               if Parsed_Field.Dot_Index /= 0 then
                  declare
                     Digit : constant Long_Long_Integer :=
                       Long_Long_Integer (Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Ch));
                  begin
                     Scale := Scale / 10.0;
                     Fraction := Fraction + Long_Long_Float (Digit) * Scale;
                  end;
               end if;
            elsif Ch /= '.' then
               return Invalid_Seconds;
            end if;
         end;
      end loop;

      if Parsed_Field.Dot_Index = 0 or else Parsed_Field.Dot_Index > Text'First then
         declare
            Last_Whole : constant Natural :=
              (if Parsed_Field.Dot_Index = 0
               then Parsed_Field.Last_Index
               else Parsed_Field.Dot_Index - 1);
            Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
              Posix_Tools.Text.Decimal_Parsing.Long_Long_Value (Text (Text'First .. Last_Whole));
         begin
            if not Parsed.Valid
              or else Parsed.Value < 0
              or else Long_Long_Float (Parsed.Value) > Max_Seconds
            then
               return Invalid_Seconds;
            end if;
            Whole := Parsed.Value;
         end;
      end if;

      Value :=
        (Long_Long_Float (Whole) + Fraction)
        * Seconds_Multiplier_For (Parsed_Field.Unit);

      if Value <= Max_Seconds then
         return (Valid => True, Value => Value);
      else
         return Invalid_Seconds;
      end if;
   end Parse_Seconds;
end Posix_Tools.Text.Duration_Fields;
