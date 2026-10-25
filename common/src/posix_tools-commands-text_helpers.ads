--  Collation, display widths and folding are in the Collation, Display
--  and Folding children.
package Posix_Tools.Commands.Text_Helpers is
   --  True for the C and POSIX locales (any letter case, any codeset), whose
   --  collation order is byte order.
   function Is_Byte_Collation_Locale (Locale : String) return Boolean;

   --  True when text in Locale is decoded as UTF-8 characters: every locale
   --  except C and POSIX, which are single-byte unless their codeset is UTF-8.
   function Is_Multibyte_Locale (Locale : String) return Boolean;

   function Parse_Long_Long_Text
     (Text  : String;
      Value : out Long_Long_Integer) return Boolean;

   function Parse_Natural_Text (Text : String; Value : out Natural) return Boolean;
end Posix_Tools.Commands.Text_Helpers;
