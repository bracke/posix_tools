--  Collation and locale classes, display widths and folding are in the
--  Collation, Display and Folding children.
package Posix_Tools.Commands.Text_Helpers is
   function Parse_Long_Long_Text
     (Text  : String;
      Value : out Long_Long_Integer) return Boolean;

   function Parse_Natural_Text (Text : String; Value : out Natural) return Boolean;
end Posix_Tools.Commands.Text_Helpers;
