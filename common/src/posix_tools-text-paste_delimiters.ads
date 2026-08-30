package Posix_Tools.Text.Paste_Delimiters
  with SPARK_Mode => On
is
   function Decoded_Delimiter_Length (Text : String) return Natural
     with
       Pre  => Text'First >= 1 and then Text'Last < Positive'Last,
       Post =>
         Decoded_Delimiter_Length'Result <= Text'Length;

   function Decode_Delimiters (Text : String) return String
     with
       Pre  => Text'First >= 1 and then Text'Last < Positive'Last,
       Post =>
         Decode_Delimiters'Result'Length <= Text'Length;

   function Delimiter (Text : String; Position : Positive) return String
     with
       Pre  => Text'First = 1,
       Post => Delimiter'Result'Length <= 1;
end Posix_Tools.Text.Paste_Delimiters;
