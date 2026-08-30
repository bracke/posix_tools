package Posix_Tools.Text.Octal_Parsing
  with SPARK_Mode => On
is
   subtype Octal_Digit_Count is Natural range 0 .. 3;
   subtype Positive_Octal_Digit_Limit is Natural range 1 .. 3;
   subtype Raw_Octal_Byte_Value is Natural range 0 .. 8#777#;

   type Parsed_Octal_Prefix is record
      Count : Octal_Digit_Count := 0;
      Value : Raw_Octal_Byte_Value := 0;
   end record;

   function Prefix_Value
     (Text       : String;
      Max_Digits : Positive_Octal_Digit_Limit) return Parsed_Octal_Prefix
     with
       Post =>
         Prefix_Value'Result.Count <= Max_Digits
         and then
           (if Prefix_Value'Result.Count = 0 then Prefix_Value'Result.Value = 0);
end Posix_Tools.Text.Octal_Parsing;
