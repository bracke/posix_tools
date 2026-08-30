with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Text.Nice_Fields
  with SPARK_Mode => On
is
   function Parse_Adjustment (Text : String) return Parsed_Adjustment is
      Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
        Posix_Tools.Text.Decimal_Parsing.Long_Long_Value (Text);
   begin
      if not Parsed.Valid
        or else Parsed.Value < -Long_Long_Integer (Integer'Last)
        or else Parsed.Value > Long_Long_Integer (Integer'Last)
      then
         return (Valid => False, Value => 0);
      end if;

      return (Valid => True, Value => Integer (Parsed.Value));
   end Parse_Adjustment;
end Posix_Tools.Text.Nice_Fields;
