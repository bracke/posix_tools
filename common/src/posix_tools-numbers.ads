package Posix_Tools.Numbers
  with SPARK_Mode => On
is
   type Count is range 0 .. 2 ** 63 - 1;
   type Parse_Status is (Valid, Empty, Invalid_Syntax, Negative_Not_Permitted, Overflow);

   type Parse_Result is record
      Status : Parse_Status := Empty;
      Value  : Count := 0;
   end record;

   subtype Digit_Value_Range is Count range 0 .. 9;

   function Is_Decimal_Digit (Ch : Character) return Boolean is
     (Ch in '0' .. '9')
     with
       Post => Is_Decimal_Digit'Result = (Ch in '0' .. '9');

   function Digit_Value (Ch : Character) return Digit_Value_Range is
     (Count (Character'Pos (Ch) - Character'Pos ('0')))
     with
       Pre  => Is_Decimal_Digit (Ch),
       Post =>
         Digit_Value'Result =
           Count (Character'Pos (Ch) - Character'Pos ('0'));

   function Contains_Only_Decimal_Digits (Text : String) return Boolean is
     (for all I in Text'Range => Is_Decimal_Digit (Text (I)))
     with
       Post =>
         Contains_Only_Decimal_Digits'Result =
           (for all I in Text'Range => Is_Decimal_Digit (Text (I)));

   function Count_Image (Value : Count) return String
     with
       Post =>
         Count_Image'Result'Length =
           (if Value < 10 then 1
            elsif Value < 100 then 2
            elsif Value < 1_000 then 3
            elsif Value < 10_000 then 4
            elsif Value < 100_000 then 5
            elsif Value < 1_000_000 then 6
            elsif Value < 10_000_000 then 7
            elsif Value < 100_000_000 then 8
            elsif Value < 1_000_000_000 then 9
            elsif Value < 10_000_000_000 then 10
            elsif Value < 100_000_000_000 then 11
            elsif Value < 1_000_000_000_000 then 12
            elsif Value < 10_000_000_000_000 then 13
            elsif Value < 100_000_000_000_000 then 14
            elsif Value < 1_000_000_000_000_000 then 15
            elsif Value < 10_000_000_000_000_000 then 16
            elsif Value < 100_000_000_000_000_000 then 17
            elsif Value < 1_000_000_000_000_000_000 then 18
            else 19);

   function Parse_Nonnegative (Text : String) return Parse_Result
     with
       Post =>
         (if Parse_Nonnegative'Result.Status /= Valid then
            Parse_Nonnegative'Result.Value = 0)
         and then
           (if Text = "" then
              Parse_Nonnegative'Result.Status = Empty)
         and then
           (if Text /= "" and then Text (Text'First) = '-' then
              Parse_Nonnegative'Result.Status = Negative_Not_Permitted)
         and then
           (if Text'Length = 1 and then Is_Decimal_Digit (Text (Text'First)) then
              Parse_Nonnegative'Result.Status = Valid
              and then
                Parse_Nonnegative'Result.Value = Digit_Value (Text (Text'First)))
         and then
           (if Text'Length = 1
             and then Text (Text'First) /= '-'
             and then not Is_Decimal_Digit (Text (Text'First))
            then
              Parse_Nonnegative'Result.Status = Invalid_Syntax)
         and then
           (if Parse_Nonnegative'Result.Status = Empty then
              Text = "")
         and then
           (if Parse_Nonnegative'Result.Status = Negative_Not_Permitted then
              Text /= "" and then Text (Text'First) = '-')
         and then
           (if Parse_Nonnegative'Result.Status = Valid then
              Text /= ""
              and then Text (Text'First) /= '-'
              and then Contains_Only_Decimal_Digits (Text))
         and then
           (if Parse_Nonnegative'Result.Status = Invalid_Syntax then
              Text /= ""
              and then Text (Text'First) /= '-'
              and then not Contains_Only_Decimal_Digits (Text));
end Posix_Tools.Numbers;
