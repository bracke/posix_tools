package Posix_Tools.Text.Suffixes
  with SPARK_Mode => On
is
   function Lowercase_Capacity (Length : Positive) return Natural
     with Post => Lowercase_Capacity'Result >= 1;

   function Lowercase_Image (Index : Natural; Length : Positive) return String
     with
       Post =>
         Lowercase_Image'Result'Length = Length
         and then
           (for all I in Lowercase_Image'Result'Range =>
              Lowercase_Image'Result (I) in 'a' .. 'z');
end Posix_Tools.Text.Suffixes;
