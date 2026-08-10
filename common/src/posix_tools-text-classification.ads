package Posix_Tools.Text.Classification is
   Unicode_Version : constant String := "15.1.0";
   Unicode_Source : constant String := "Unicode Character Database PropList.txt White_Space property";

   function Is_Whitespace (Code_Point : Long_Long_Integer) return Boolean;
end Posix_Tools.Text.Classification;
