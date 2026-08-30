package Posix_Tools.Text.NL_Fields
  with SPARK_Mode => On
is
   type Number_Mode is (Unknown_Number_Mode, All_Lines, Nonempty_Lines, No_Lines);
   type Logical_Section is (No_Section, Header_Section, Body_Section, Footer_Section);

   type Parsed_Long_Long is record
      Valid : Boolean;
      Value : Long_Long_Integer;
   end record;

   function Is_Empty_Line (Line : String) return Boolean;

   function Logical_Section_For
     (Line : String;
      First_Delimiter : Character;
      Second_Delimiter : Character) return Logical_Section;

   function Mode_For (Text : String) return Number_Mode;

   function Positive_Long_Value (Text : String) return Parsed_Long_Long
     with Post =>
       (if Positive_Long_Value'Result.Valid then
          Positive_Long_Value'Result.Value > 0
          and then Text /= ""
          and then Text (Text'First) not in '+' | '-'
        else
          Positive_Long_Value'Result.Value = 0);
end Posix_Tools.Text.NL_Fields;
