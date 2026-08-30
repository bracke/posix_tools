with Posix_Tools.Numbers;

package body Posix_Tools.Wc_Fields
  with SPARK_Mode => On
is
   function Count_Image (Value : Nonnegative_Count) return String is
      Rendered : constant String :=
        Posix_Tools.Numbers.Count_Image (Posix_Tools.Numbers.Count (Value));
   begin
      pragma Assert (Rendered'Length = Decimal_Width (Value));
      return Rendered;
   end Count_Image;

   function Decimal_Width (Value : Nonnegative_Count) return Decimal_Width_Range is
   begin
      if Value < 10 then
         return 1;
      elsif Value < 100 then
         return 2;
      elsif Value < 1_000 then
         return 3;
      elsif Value < 10_000 then
         return 4;
      elsif Value < 100_000 then
         return 5;
      elsif Value < 1_000_000 then
         return 6;
      elsif Value < 10_000_000 then
         return 7;
      elsif Value < 100_000_000 then
         return 8;
      elsif Value < 1_000_000_000 then
         return 9;
      elsif Value < 10_000_000_000 then
         return 10;
      elsif Value < 100_000_000_000 then
         return 11;
      elsif Value < 1_000_000_000_000 then
         return 12;
      elsif Value < 10_000_000_000_000 then
         return 13;
      elsif Value < 100_000_000_000_000 then
         return 14;
      elsif Value < 1_000_000_000_000_000 then
         return 15;
      elsif Value < 10_000_000_000_000_000 then
         return 16;
      elsif Value < 100_000_000_000_000_000 then
         return 17;
      elsif Value < 1_000_000_000_000_000_000 then
         return 18;
      else
         return 19;
      end if;
   end Decimal_Width;

   function Selected_Field_Count (Selection : Count_Selection) return Field_Count is
      Result : Field_Count := 0;
   begin
      if Selection.Lines then
         Result := Result + 1;
      end if;
      if Selection.Words then
         Result := Result + 1;
      end if;
      if Selection.Bytes then
         Result := Result + 1;
      end if;
      if Selection.Characters then
         Result := Result + 1;
      end if;
      if Selection.Max_Line_Length then
         Result := Result + 1;
      end if;

      return Result;
   end Selected_Field_Count;
end Posix_Tools.Wc_Fields;
