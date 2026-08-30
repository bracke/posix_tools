package body Posix_Tools.Numbers
  with SPARK_Mode => On
is
   function Count_Image (Value : Count) return String is
      function Decimal_Length (Item : Count) return Positive is
        (if Item < 10 then 1
         elsif Item < 100 then 2
         elsif Item < 1_000 then 3
         elsif Item < 10_000 then 4
         elsif Item < 100_000 then 5
         elsif Item < 1_000_000 then 6
         elsif Item < 10_000_000 then 7
         elsif Item < 100_000_000 then 8
         elsif Item < 1_000_000_000 then 9
         elsif Item < 10_000_000_000 then 10
         elsif Item < 100_000_000_000 then 11
         elsif Item < 1_000_000_000_000 then 12
         elsif Item < 10_000_000_000_000 then 13
         elsif Item < 100_000_000_000_000 then 14
         elsif Item < 1_000_000_000_000_000 then 15
         elsif Item < 10_000_000_000_000_000 then 16
         elsif Item < 100_000_000_000_000_000 then 17
         elsif Item < 1_000_000_000_000_000_000 then 18
         else 19);

      Result    : String (1 .. Decimal_Length (Value));
      Remaining : Count := Value;
   begin
      for I in reverse Result'Range loop
         declare
            Digit : constant Count := Remaining mod 10;
         begin
            pragma Assert (Digit <= 9);
            pragma Assert (Character'Pos ('0') + Integer (Digit) <= Character'Pos ('9'));
            Result (I) :=
              Character'Val
                (Character'Pos ('0') + Integer (Digit));
         end;
         Remaining := Remaining / 10;
      end loop;

      return Result;
   end Count_Image;

   function Parse_Nonnegative (Text : String) return Parse_Result is
      Value : Count := 0;
   begin
      if Text = "" then
         return (Status => Empty, Value => 0);
      elsif Text (Text'First) = '-' then
         return (Status => Negative_Not_Permitted, Value => 0);
      elsif Text'Length = 1 then
         if Is_Decimal_Digit (Text (Text'First)) then
            return
              (Status => Valid,
               Value  => Digit_Value (Text (Text'First)));
         else
            return (Status => Invalid_Syntax, Value => 0);
         end if;
      end if;

      for I in Text'Range loop
         declare
            Ch : constant Character := Text (I);
         begin
            if not Is_Decimal_Digit (Ch) then
               return (Status => Invalid_Syntax, Value => 0);
            end if;

            if Value > (Count'Last - Digit_Value (Ch)) / 10 then
               return (Status => Overflow, Value => 0);
            end if;

            Value := Value * 10 + Digit_Value (Ch);
         end;

         pragma Loop_Invariant
           (for all J in Text'First .. I => Is_Decimal_Digit (Text (J)));
      end loop;

      return (Status => Valid, Value => Value);
   end Parse_Nonnegative;
end Posix_Tools.Numbers;
