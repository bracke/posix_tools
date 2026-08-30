with Posix_Tools.Text.Byte_Classes;

package Posix_Tools.Text.Hex_Digests
  with SPARK_Mode => On
is
   function Is_SHA256_Digest (Text : String) return Boolean
     with Post =>
       Is_SHA256_Digest'Result =
         (Text'Length = 64
          and then
            (for all I in Text'Range =>
               Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit (Text (I))));
end Posix_Tools.Text.Hex_Digests;
