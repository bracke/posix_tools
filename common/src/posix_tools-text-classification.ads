package Posix_Tools.Text.Classification
  with SPARK_Mode => On
is
   Unicode_Version : constant String := "15.1.0";
   Unicode_Source : constant String := "Unicode Character Database PropList.txt White_Space property";

   function Is_Unicode_Scalar (Code_Point : Long_Long_Integer) return Boolean is
     (Code_Point in 0 .. 16#10FFFF#
      and then not (Code_Point in 16#D800# .. 16#DFFF#));

   function Is_Whitespace (Code_Point : Long_Long_Integer) return Boolean;
end Posix_Tools.Text.Classification;
