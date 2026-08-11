package Posix_Tools.Wc_Fields
  with SPARK_Mode => On
is
   subtype Nonnegative_Count is Long_Long_Integer range 0 .. Long_Long_Integer'Last;
   subtype Decimal_Width_Range is Positive range 1 .. 19;
   subtype Field_Count is Natural range 0 .. 4;

   type Count_Selection is record
      Lines      : Boolean := False;
      Words      : Boolean := False;
      Bytes      : Boolean := False;
      Characters : Boolean := False;
   end record;

   function Decimal_Width (Value : Nonnegative_Count) return Decimal_Width_Range;

   function Selected_Field_Count (Selection : Count_Selection) return Field_Count;

   function Needs_Text_Decoding (Selection : Count_Selection) return Boolean is
     (Selection.Words or else Selection.Characters);
end Posix_Tools.Wc_Fields;
