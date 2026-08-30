package Posix_Tools.Text.Printf_Escapes
  with SPARK_Mode => On
is
   function Stop_Decoding (Text : String) return Boolean;

   function Decoded_Length (Text : String) return Natural
     with
       Post => Decoded_Length'Result <= Text'Length;

   function Decode_Backslash_Text (Text : String) return String
     with
       Post => Decode_Backslash_Text'Result'Length <= Text'Length;
end Posix_Tools.Text.Printf_Escapes;
