with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Commands.Text_Helpers.Display;
with Posix_Tools.Commands.Text_Helpers.Folding;
with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Commands.Text_Helpers is
   function Translation_Set_From_Spec (Text, Locale : String) return String is
   begin
      return Posix_Tools.Commands.Text_Helpers.Collation.Translation_Set_From_Spec
        (Text, Locale);
   end Translation_Set_From_Spec;

   function Locale_Collation_Order (Locale, Set1 : String) return String is
   begin
      return Posix_Tools.Commands.Text_Helpers.Collation.Locale_Collation_Order
        (Locale, Set1);
   end Locale_Collation_Order;

   function Locale_Family (Locale : String) return String is
   begin
      return Posix_Tools.Commands.Text_Helpers.Collation.Locale_Family (Locale);
   end Locale_Family;

   function Folded_Sort_Text (Text : String) return String is
   begin
      return Posix_Tools.Commands.Text_Helpers.Folding.Folded_Sort_Text (Text);
   end Folded_Sort_Text;

   function Locale_Sort_Text (Locale, Text : String) return String is
   begin
      return Posix_Tools.Commands.Text_Helpers.Collation.Locale_Sort_Text
        (Locale, Text);
   end Locale_Sort_Text;

   function Display_Next_Column
     (Text     : String;
      Index    : Positive;
      Column   : Natural;
      Consumed : out Natural) return Natural
   is
   begin
      return Posix_Tools.Commands.Text_Helpers.Display.Display_Next_Column
        (Text, Index, Column, Consumed);
   end Display_Next_Column;

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
end Posix_Tools.Commands.Text_Helpers;
