package body Posix_Tools.Wc_Fields
  with SPARK_Mode => On
is
   function Decimal_Width (Value : Nonnegative_Count) return Decimal_Width_Range is
      Current : Nonnegative_Count := Value;
      Width   : Decimal_Width_Range := 1;
   begin
      while Current >= 10 loop
         pragma Loop_Variant (Decreases => Current);
         Current := Current / 10;
         Width := Width + 1;
      end loop;

      return Width;
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

      return Result;
   end Selected_Field_Count;
end Posix_Tools.Wc_Fields;
