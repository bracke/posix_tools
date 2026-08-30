package Posix_Tools.Wc_Fields
  with SPARK_Mode => On
is
   subtype Nonnegative_Count is Long_Long_Integer range 0 .. Long_Long_Integer'Last;
   subtype Decimal_Width_Range is Positive range 1 .. 19;
   subtype Field_Count is Natural range 0 .. 5;

   type Count_Selection is record
      Lines      : Boolean := False;
      Words      : Boolean := False;
      Bytes      : Boolean := False;
      Characters : Boolean := False;
      Max_Line_Length : Boolean := False;
   end record;

   function Decimal_Width (Value : Nonnegative_Count) return Decimal_Width_Range
     with
       Post =>
         Decimal_Width'Result =
           (if Value < 10 then 1
            elsif Value < 100 then 2
            elsif Value < 1_000 then 3
            elsif Value < 10_000 then 4
            elsif Value < 100_000 then 5
            elsif Value < 1_000_000 then 6
            elsif Value < 10_000_000 then 7
            elsif Value < 100_000_000 then 8
            elsif Value < 1_000_000_000 then 9
            elsif Value < 10_000_000_000 then 10
            elsif Value < 100_000_000_000 then 11
            elsif Value < 1_000_000_000_000 then 12
            elsif Value < 10_000_000_000_000 then 13
            elsif Value < 100_000_000_000_000 then 14
            elsif Value < 1_000_000_000_000_000 then 15
            elsif Value < 10_000_000_000_000_000 then 16
            elsif Value < 100_000_000_000_000_000 then 17
            elsif Value < 1_000_000_000_000_000_000 then 18
            else 19);

   function Count_Image (Value : Nonnegative_Count) return String
     with
       Post => Count_Image'Result'Length = Decimal_Width (Value);

   function Selected_Field_Count (Selection : Count_Selection) return Field_Count
     with
       Post =>
         Selected_Field_Count'Result =
           Boolean'Pos (Selection.Lines)
           + Boolean'Pos (Selection.Words)
           + Boolean'Pos (Selection.Bytes)
           + Boolean'Pos (Selection.Characters)
           + Boolean'Pos (Selection.Max_Line_Length);

   function Needs_Text_Decoding (Selection : Count_Selection) return Boolean is
     (Selection.Words or else Selection.Characters or else Selection.Max_Line_Length)
     with
       Post =>
         Needs_Text_Decoding'Result =
           (Selection.Words or else Selection.Characters or else Selection.Max_Line_Length);
end Posix_Tools.Wc_Fields;
