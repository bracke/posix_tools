package Posix_Tools.Commands.Text_Helpers is
   function Translation_Set_From_Spec (Text, Locale : String) return String;

   function Display_Next_Column
     (Text     : String;
      Index    : Positive;
      Column   : Natural;
      Consumed : out Natural) return Natural;

   function Folded_Sort_Text (Text : String) return String;

   function Locale_Collation_Order (Locale, Set1 : String) return String;

   function Locale_Family (Locale : String) return String;

   function Locale_Sort_Text (Locale, Text : String) return String;

   function Parse_Long_Long_Text
     (Text  : String;
      Value : out Long_Long_Integer) return Boolean;

   function Parse_Natural_Text (Text : String; Value : out Natural) return Boolean;
end Posix_Tools.Commands.Text_Helpers;
