package Posix_Tools.Text.Nice_Fields
  with SPARK_Mode => On
is
   type Parsed_Adjustment is record
      Valid : Boolean := False;
      Value : Integer := 0;
   end record;

   function Parse_Adjustment (Text : String) return Parsed_Adjustment
     with
       Post =>
         (if not Parse_Adjustment'Result.Valid then Parse_Adjustment'Result.Value = 0);
end Posix_Tools.Text.Nice_Fields;
