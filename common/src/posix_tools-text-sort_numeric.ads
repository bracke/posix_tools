package Posix_Tools.Text.Sort_Numeric is
   function Canonical_Decimal (Value : String) return String;
   function Decimal_Sort_Key (Value : String) return String;

   function Decimal_Compare
     (Left, Right : String;
      Canonical   : Boolean := False) return Integer;

   function Numeric_Compare (Locale, Left, Right : String) return Integer;

   function Numeric_Field (Locale, Text : String) return String;
   function Numeric_Field
     (Locale : String;
      Text   : String;
      First  : Positive;
      Last   : Natural;
      ASCII_Format : Boolean := False) return String;
end Posix_Tools.Text.Sort_Numeric;
