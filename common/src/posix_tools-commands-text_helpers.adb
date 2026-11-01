with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Commands.Text_Helpers is
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
