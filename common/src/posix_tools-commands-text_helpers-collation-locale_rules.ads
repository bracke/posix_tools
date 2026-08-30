private package Posix_Tools.Commands.Text_Helpers.Collation.Locale_Rules is
   function Locale_Collating_Symbol (Locale, Element : String) return String;
   function Locale_Collation_Order (Locale, Set1 : String) return String;
   function Locale_Equivalence_Class (Locale, Element : String) return String;
   function Locale_Family (Locale : String) return String;
end Posix_Tools.Commands.Text_Helpers.Collation.Locale_Rules;
