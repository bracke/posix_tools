package Posix_Tools.Text.Numeric_Images
  with SPARK_Mode => On
is
   function Integer_Image (Value : Integer) return String;

   function Long_Long_Integer_Image (Value : Long_Long_Integer) return String;

   function Natural_Image (Value : Natural) return String;

   function Fixed_Decimal_Image (Value : Natural; Width : Positive) return String
     with
       Post =>
         Fixed_Decimal_Image'Result'Length = Width
         and then
           (for all I in Fixed_Decimal_Image'Result'Range =>
              Fixed_Decimal_Image'Result (I) in '0' .. '9');

   function Fixed_Hex_Image (Value : Natural; Width : Positive) return String
     with
       Post =>
         Fixed_Hex_Image'Result'Length = Width
         and then
           (for all I in Fixed_Hex_Image'Result'Range =>
              Fixed_Hex_Image'Result (I) in '0' .. '9' | 'a' .. 'f');

   function Fixed_Octal_Image (Value : Natural; Width : Positive) return String
     with
       Post =>
         Fixed_Octal_Image'Result'Length = Width
         and then
           (for all I in Fixed_Octal_Image'Result'Range =>
              Fixed_Octal_Image'Result (I) in '0' .. '7');

   function Four_Digit_Image (Value : Natural) return String
     with
       Pre  => Value <= 9_999,
       Post =>
         Four_Digit_Image'Result'Length = 4
         and then
           (for all I in Four_Digit_Image'Result'Range =>
              Four_Digit_Image'Result (I) in '0' .. '9');

   function Space_Two_Image (Value : Natural) return String
     with
       Pre  => Value <= 99,
       Post =>
         Space_Two_Image'Result'Length = 2
         and then
           Space_Two_Image'Result (Space_Two_Image'Result'First) in ' ' | '0' .. '9'
         and then
           Space_Two_Image'Result (Space_Two_Image'Result'Last) in '0' .. '9';

   function Three_Digit_Image (Value : Natural) return String
     with
       Pre  => Value <= 999,
       Post =>
         Three_Digit_Image'Result'Length = 3
         and then
           (for all I in Three_Digit_Image'Result'Range =>
              Three_Digit_Image'Result (I) in '0' .. '9');

   function Two_Digit_Image (Value : Natural) return String
     with
       Pre  => Value <= 99,
       Post =>
         Two_Digit_Image'Result'Length = 2
         and then
           (for all I in Two_Digit_Image'Result'Range =>
              Two_Digit_Image'Result (I) in '0' .. '9');
end Posix_Tools.Text.Numeric_Images;
