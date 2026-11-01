package Posix_Tools.Commands.Text_Helpers.Collation is
   --  How Left orders against Right in Locale, as test's < and > compare
   --  strings: negative before, zero equal, positive after. Bytes order them
   --  in the C and POSIX locales; elsewhere the locale's collation does.
   function Compare (Locale, Left, Right : String) return Integer;

   --  True for the C and POSIX locales (any letter case, any codeset), whose
   --  collation order is byte order.
   function Is_Byte_Collation_Locale (Locale : String) return Boolean;

   --  True when text in Locale is decoded as UTF-8 characters: every locale
   --  except C and POSIX, which are single-byte unless their codeset is UTF-8.
   function Is_Multibyte_Locale (Locale : String) return Boolean;

   --  The collating element Element names in a [.element.] of Locale.
   function Locale_Collating_Symbol (Locale, Element : String) return String;

   function Locale_Collation_Order (Locale, Set1 : String) return String;

   --  The characters of Element's [=element=] equivalence class in Locale,
   --  Element first.
   function Locale_Equivalence_Class (Locale, Element : String) return String;

   function Locale_Family (Locale : String) return String;

   function Locale_Sort_Text (Locale, Text : String) return String;
end Posix_Tools.Commands.Text_Helpers.Collation;
