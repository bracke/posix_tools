with Posix_Tools.Text.Byte_Classes;

package body Posix_Tools.Text.Octal_Parsing
  with SPARK_Mode => On
is
   function Prefix_Value
     (Text       : String;
      Max_Digits : Positive_Octal_Digit_Limit) return Parsed_Octal_Prefix
   is
      Count : Octal_Digit_Count := 0;
      Value : Raw_Octal_Byte_Value := 0;
   begin
      while Count < Text'Length and then Count < Max_Digits loop
         pragma Loop_Invariant (Count <= Max_Digits);
         pragma Loop_Invariant (Count <= Text'Length);
         pragma Loop_Invariant (if Count = 0 then Value = 0);
         pragma Loop_Invariant (if Count = 1 then Value <= 8#7#);
         pragma Loop_Invariant (if Count = 2 then Value <= 8#77#);
         pragma Loop_Invariant (if Count = 3 then Value <= 8#777#);
         pragma Loop_Invariant (Value <= 8#777#);
         pragma Loop_Variant (Increases => Count);

         if not Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit
             (Text (Text'First + Count))
         then
            return (Count => Count, Value => Value);
         end if;

         Value :=
           Value * 8
           + Posix_Tools.Text.Byte_Classes.ASCII_Octal_Digit_Value
             (Text (Text'First + Count));
         Count := Count + 1;
      end loop;

      return (Count => Count, Value => Value);
   end Prefix_Value;
end Posix_Tools.Text.Octal_Parsing;
