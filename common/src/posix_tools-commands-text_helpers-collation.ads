package Posix_Tools.Commands.Text_Helpers.Collation is
   function Locale_Collation_Order (Locale, Set1 : String) return String;

   function Locale_Family (Locale : String) return String;

   function Locale_Sort_Text (Locale, Text : String) return String;

   function Translation_Set_From_Spec (Text, Locale : String) return String;
end Posix_Tools.Commands.Text_Helpers.Collation;
