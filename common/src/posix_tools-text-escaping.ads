package Posix_Tools.Text.Escaping
  with SPARK_Mode => On
is
   function Needs_Escaping (Ch : Character) return Boolean
     with
       Post =>
         Needs_Escaping'Result =
           (Character'Pos (Ch) < 32 or else Character'Pos (Ch) = 127);

   function Escaped_Character_Length (Ch : Character) return Positive
     with
       Post =>
         (if Needs_Escaping (Ch) then Escaped_Character_Length'Result = 4
          else Escaped_Character_Length'Result = 1);

   function Escaped_Length (Text : String) return Long_Long_Integer
     with
       Post =>
         Escaped_Length'Result >= Long_Long_Integer (Text'Length)
         and then Escaped_Length'Result <= Long_Long_Integer (Text'Length) * 4;

   function Escape_Untrusted (Text : String) return String
     with
       Pre => Text'Length <= Natural'Last / 4,
       Post =>
         Escape_Untrusted'Result'Length >= Text'Length
         and then Escape_Untrusted'Result'Length <= Text'Length * 4;
end Posix_Tools.Text.Escaping;
