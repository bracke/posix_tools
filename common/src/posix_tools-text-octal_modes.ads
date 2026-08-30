package Posix_Tools.Text.Octal_Modes
  with SPARK_Mode => On
is
   type Parsed_Mode is record
      Valid : Boolean := False;
      Value : Natural := 0;
   end record;

   function Parse_Mode (Text : String) return Parsed_Mode
     with
       Post =>
         (if Parse_Mode'Result.Valid then
            Parse_Mode'Result.Value = Mode_Value (Text)
          else
            Parse_Mode'Result.Value = 0);

   function Valid_Mode (Text : String) return Boolean;

   function Mode_Value (Text : String) return Natural;
end Posix_Tools.Text.Octal_Modes;
