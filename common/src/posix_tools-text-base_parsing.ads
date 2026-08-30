package Posix_Tools.Text.Base_Parsing
  with SPARK_Mode => On
is
   subtype Number_Base is Natural range 2 .. 16;

   type Parsed_Natural is record
      Valid : Boolean := False;
      Value : Natural := 0;
   end record;

   function Natural_Value (Text : String; Base : Number_Base) return Parsed_Natural
     with
       Post =>
         (if not Natural_Value'Result.Valid then Natural_Value'Result.Value = 0);

   function Scaled_Natural_Value
     (Text       : String;
      Base       : Number_Base;
      Multiplier : Positive) return Parsed_Natural
     with
       Post =>
         (if not Scaled_Natural_Value'Result.Valid then Scaled_Natural_Value'Result.Value = 0);
end Posix_Tools.Text.Base_Parsing;
