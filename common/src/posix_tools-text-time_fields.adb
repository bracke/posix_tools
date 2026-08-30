with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Text.Time_Fields
  with SPARK_Mode => On
is
   function Day_Of_Year (Year, Month, Day : Natural) return Natural is
   begin
      return
        (case Month is
           when 1 => Day,
           when 2 => 31 + Day,
           when 3 => 59 + (if Is_Leap_Year (Year) then 1 else 0) + Day,
           when 4 => 90 + (if Is_Leap_Year (Year) then 1 else 0) + Day,
           when 5 => 120 + (if Is_Leap_Year (Year) then 1 else 0) + Day,
           when 6 => 151 + (if Is_Leap_Year (Year) then 1 else 0) + Day,
           when 7 => 181 + (if Is_Leap_Year (Year) then 1 else 0) + Day,
           when 8 => 212 + (if Is_Leap_Year (Year) then 1 else 0) + Day,
           when 9 => 243 + (if Is_Leap_Year (Year) then 1 else 0) + Day,
           when 10 => 273 + (if Is_Leap_Year (Year) then 1 else 0) + Day,
           when 11 => 304 + (if Is_Leap_Year (Year) then 1 else 0) + Day,
           when others => 334 + (if Is_Leap_Year (Year) then 1 else 0) + Day);
   end Day_Of_Year;

   function Days_In_Month (Year, Month : Natural) return Natural is
   begin
      return
        (case Month is
           when 1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
           when 4 | 6 | 9 | 11 => 30,
           when others => (if Is_Leap_Year (Year) then 29 else 28));
   end Days_In_Month;

   function Invalid return Parsed_Time
     with
       Post =>
         not Invalid'Result.Valid
         and then Invalid'Result.Hour = 0
         and then Invalid'Result.Minute = 0
         and then Invalid'Result.Second = 0;

   function Invalid return Parsed_Time is
   begin
      return (Valid => False, Hour => 0, Minute => 0, Second => 0);
   end Invalid;

   function Invalid_Offset return Parsed_Time_Offset
     with
       Post =>
         not Invalid_Offset'Result.Valid
         and then Invalid_Offset'Result.Minutes = 0;

   function Invalid_Offset return Parsed_Time_Offset is
   begin
      return (Valid => False, Minutes => 0);
   end Invalid_Offset;

   function Is_Leap_Year (Year : Natural) return Boolean is
   begin
      return (Year mod 4 = 0 and then Year mod 100 /= 0) or else Year mod 400 = 0;
   end Is_Leap_Year;

   function Parse_HM_Or_HMS (Value : String) return Parsed_Time
   is
      Processed    : Natural := 0;
      Field        : Natural := 1;
      Field_Digits : Natural := 0;
      Current      : Natural := 0;
      Hour         : Natural := 0;
      Minute       : Natural := 0;
   begin
      if Value = "" then
         return Invalid;
      end if;

      while Processed < Value'Length loop
         pragma Loop_Invariant (Processed <= Value'Length);
         pragma Loop_Invariant (Field in 1 .. 3);
         pragma Loop_Invariant (Hour <= 23);
         pragma Loop_Invariant (Minute <= 59);
         pragma Loop_Invariant (Field_Digits <= Processed);
         pragma Loop_Variant (Increases => Processed);

         declare
            Ch : constant Character := Value (Value'First + Processed);
         begin
            if Ch = ':' then
               if Field_Digits = 0 then
                  return Invalid;
               elsif Field = 1 then
                  if Current > 23 then
                     return Invalid;
                  end if;
                  Hour := Current;
               elsif Field = 2 then
                  if Current > 59 then
                     return Invalid;
                  end if;
                  Minute := Current;
               else
                  return Invalid;
               end if;

               Field := Field + 1;
               Current := 0;
               Field_Digits := 0;
            elsif Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Ch) then
               declare
                  Digit : constant Natural :=
                    Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Ch);
               begin
                  if Field_Digits = Natural'Last
                    or else Current > (Natural'Last - Digit) / 10
                  then
                     return Invalid;
                  end if;

                  Current := Current * 10 + Digit;
                  Field_Digits := Field_Digits + 1;
               end;
            else
               return Invalid;
            end if;
         end;

         Processed := Processed + 1;
      end loop;

      if Field_Digits = 0 then
         return Invalid;
      elsif Field = 2 then
         if Current > 59 then
            return Invalid;
         end if;

         return (Valid => True, Hour => Hour, Minute => Current, Second => 0);
      elsif Field = 3 then
         if Current > 59 then
            return Invalid;
         end if;

         return (Valid => True, Hour => Hour, Minute => Minute, Second => Current);
      else
         return Invalid;
      end if;
   end Parse_HM_Or_HMS;

   function Parse_ISO_Time_Zone_Offset (Value : String) return Parsed_Time_Offset is
      Sign         : Integer := 1;
      Hour         : Natural;
      Minute_Value : Natural := 0;
   begin
      if Value = "Z" then
         return (Valid => True, Minutes => 0);
      elsif Value'Length < 3 then
         return Invalid_Offset;
      elsif Value (Value'First) = '-' then
         Sign := -1;
      elsif Value (Value'First) /= '+' then
         return Invalid_Offset;
      end if;

      if Value'Length = 3 then
         declare
            Parsed_Hour : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
              Posix_Tools.Text.Decimal_Parsing.Natural_In_Range
                (Value (Value'First + 1 .. Value'First + 2), 0, 23);
         begin
            if not Parsed_Hour.Valid then
               return Invalid_Offset;
            end if;

            Hour := Parsed_Hour.Value;
         end;
      elsif Value'Length = 5 then
         declare
            Parsed_Hour : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
              Posix_Tools.Text.Decimal_Parsing.Natural_In_Range
                (Value (Value'First + 1 .. Value'First + 2), 0, 23);
            Parsed_Minute : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
              Posix_Tools.Text.Decimal_Parsing.Natural_In_Range
                (Value (Value'First + 3 .. Value'First + 4), 0, 59);
         begin
            if not Parsed_Hour.Valid or else not Parsed_Minute.Valid then
               return Invalid_Offset;
            end if;

            Hour := Parsed_Hour.Value;
            Minute_Value := Parsed_Minute.Value;
         end;
      elsif Value'Length = 6 and then Value (Value'First + 3) = ':' then
         declare
            Parsed_Hour : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
              Posix_Tools.Text.Decimal_Parsing.Natural_In_Range
                (Value (Value'First + 1 .. Value'First + 2), 0, 23);
            Parsed_Minute : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
              Posix_Tools.Text.Decimal_Parsing.Natural_In_Range
                (Value (Value'First + 4 .. Value'First + 5), 0, 59);
         begin
            if not Parsed_Hour.Valid or else not Parsed_Minute.Valid then
               return Invalid_Offset;
            end if;

            Hour := Parsed_Hour.Value;
            Minute_Value := Parsed_Minute.Value;
         end;
      else
         return Invalid_Offset;
      end if;

      return (Valid => True, Minutes => Sign * Integer (Hour * 60 + Minute_Value));
   end Parse_ISO_Time_Zone_Offset;

   function Parse_POSIX_Time_Zone_Offset (Value : String) return Parsed_Time_Offset is
      Sign         : Integer := 1;
      Hour         : Natural;
      Minute_Value : Natural := 0;
   begin
      if Value = "" then
         return (Valid => True, Minutes => 0);
      end if;

      declare
         First : Positive := Value'First;
      begin
         if Value (First) = '+' then
            if First = Value'Last then
               return Invalid_Offset;
            end if;

            Sign := 1;
            First := First + 1;
         elsif Value (First) = '-' then
            if First = Value'Last then
               return Invalid_Offset;
            end if;

            Sign := -1;
            First := First + 1;
         end if;

            declare
               Remainder : constant String := Value (First .. Value'Last);
            begin
               if Remainder'Length in 1 | 2 then
                  declare
                     Parsed_Hour : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
                       Posix_Tools.Text.Decimal_Parsing.Natural_In_Range (Remainder, 0, 23);
                  begin
                     if not Parsed_Hour.Valid then
                        return Invalid_Offset;
                     end if;

                     Hour := Parsed_Hour.Value;
                  end;
               elsif Remainder'Length = 4 then
                  declare
                     Parsed_Hour : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
                       Posix_Tools.Text.Decimal_Parsing.Natural_In_Range
                         (Remainder (Remainder'First .. Remainder'First + 1), 0, 23);
                     Parsed_Minute : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
                       Posix_Tools.Text.Decimal_Parsing.Natural_In_Range
                         (Remainder (Remainder'First + 2 .. Remainder'First + 3), 0, 59);
                  begin
                     if not Parsed_Hour.Valid or else not Parsed_Minute.Valid then
                        return Invalid_Offset;
                     end if;

                     Hour := Parsed_Hour.Value;
                     Minute_Value := Parsed_Minute.Value;
                  end;
               elsif Remainder'Length in 3 | 5
                 and then Remainder (Remainder'Last - 2) = ':'
               then
                  declare
                     Hour_Text : constant String := Remainder (Remainder'First .. Remainder'Last - 3);
                     Minute_Text : constant String := Remainder (Remainder'Last - 1 .. Remainder'Last);
                     Parsed_Hour : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
                       Posix_Tools.Text.Decimal_Parsing.Natural_In_Range (Hour_Text, 0, 23);
                     Parsed_Minute : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
                       Posix_Tools.Text.Decimal_Parsing.Natural_In_Range (Minute_Text, 0, 59);
                  begin
                     if Hour_Text'Length not in 1 | 2
                       or else not Parsed_Hour.Valid
                       or else not Parsed_Minute.Valid
                     then
                        return Invalid_Offset;
                     end if;

                     Hour := Parsed_Hour.Value;
                     Minute_Value := Parsed_Minute.Value;
                  end;
               else
                  return Invalid_Offset;
               end if;
            end;

         return (Valid => True, Minutes => Sign * Integer (Hour * 60 + Minute_Value));
      end;
   end Parse_POSIX_Time_Zone_Offset;
end Posix_Tools.Text.Time_Fields;
