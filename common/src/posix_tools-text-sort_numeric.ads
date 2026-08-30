package Posix_Tools.Text.Sort_Numeric is
   function Decimal_Compare (Left, Right : String) return Integer;

   function Numeric_Compare (Locale, Left, Right : String) return Integer;

   function Numeric_Field (Locale, Text : String) return String;
end Posix_Tools.Text.Sort_Numeric;
