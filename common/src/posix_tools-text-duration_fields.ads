package Posix_Tools.Text.Duration_Fields
  with SPARK_Mode => On
is
   type Duration_Unit is (Seconds, Minutes, Hours, Days);

   type Parsed_Duration_Field is record
      Valid : Boolean := False;
      Last_Index : Natural := 0;
      Dot_Index : Natural := 0;
      Unit : Duration_Unit := Seconds;
   end record;

   type Parsed_Duration_Milliseconds is record
      Valid : Boolean := False;
      Value : Natural := 0;
   end record;

   type Parsed_Duration_Seconds is record
      Valid : Boolean := False;
      Value : Long_Long_Float := 0.0;
   end record;

   function Parse_Field (Text : String) return Parsed_Duration_Field
     with
       Post =>
         (if Parse_Field'Result.Valid then
            Text /= ""
            and then Parse_Field'Result.Last_Index in Text'Range
            and then
              (Parse_Field'Result.Dot_Index = 0
               or else Parse_Field'Result.Dot_Index in Text'First .. Parse_Field'Result.Last_Index)
          else
            Parse_Field'Result.Last_Index = 0
            and then Parse_Field'Result.Dot_Index = 0);

   function Parse_Milliseconds (Text : String) return Parsed_Duration_Milliseconds
     with
       Post =>
         (if Parse_Milliseconds'Result.Valid then
            Parse_Milliseconds'Result.Value <= Natural'Last
          else
            Parse_Milliseconds'Result.Value = 0);

   function Parse_Seconds
     (Text        : String;
      Max_Seconds : Long_Long_Float) return Parsed_Duration_Seconds
     with
       Pre => Max_Seconds >= 0.0,
       Post =>
         (if Parse_Seconds'Result.Valid then
            Parse_Seconds'Result.Value <= Max_Seconds
          else
            Parse_Seconds'Result.Value = 0.0);
end Posix_Tools.Text.Duration_Fields;
