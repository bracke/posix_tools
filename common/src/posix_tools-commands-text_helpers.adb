with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Commands.Text_Helpers is

   function Is_Byte_Collation_Locale (Locale : String) return Boolean is
      Family : constant String :=
        Ada.Characters.Handling.To_Lower (Posix_Tools.Commands.Text_Helpers.Collation.Locale_Family (Locale));
   begin
      return Family in "" | "c" | "posix";
   end Is_Byte_Collation_Locale;

   function Is_Multibyte_Locale (Locale : String) return Boolean is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Locale);
   begin
      return not Is_Byte_Collation_Locale (Locale)
        or else Ada.Strings.Fixed.Index (Lower, ".utf-8") > 0
        or else Ada.Strings.Fixed.Index (Lower, ".utf8") > 0;
   end Is_Multibyte_Locale;

   function Parse_Long_Long_Text
     (Text  : String;
      Value : out Long_Long_Integer) return Boolean
   is
      Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
        Posix_Tools.Text.Decimal_Parsing.Long_Long_Value (Text);
   begin
      if Parsed.Valid then
         Value := Parsed.Value;
         return True;
      else
         Value := 0;
         return False;
      end if;
   end Parse_Long_Long_Text;

   function Parse_Natural_Text (Text : String; Value : out Natural) return Boolean is
      Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
        Posix_Tools.Text.Decimal_Parsing.Natural_Value (Text);
   begin
      if Parsed.Valid then
         Value := Parsed.Value;
         return True;
      else
         Value := 0;
         return False;
      end if;
   end Parse_Natural_Text;
end Posix_Tools.Commands.Text_Helpers;
