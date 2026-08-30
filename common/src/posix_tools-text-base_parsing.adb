with Posix_Tools.Text.Byte_Classes;

package body Posix_Tools.Text.Base_Parsing
  with SPARK_Mode => On
is
   function Natural_Value (Text : String; Base : Number_Base) return Parsed_Natural
   is
      Acc       : Natural := 0;
      Processed : Natural := 0;
   begin
      if Text = "" then
         return (Valid => False, Value => 0);
      end if;

      while Processed < Text'Length loop
         pragma Loop_Invariant (Processed <= Text'Length);
         pragma Loop_Variant (Increases => Processed);

         declare
            Ch    : constant Character := Text (Text'First + Processed);
            Digit : Natural;
         begin
            if not Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit (Ch) then
               return (Valid => False, Value => 0);
            end if;

            Digit := Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Value (Ch);
            if Digit >= Base or else Acc > (Natural'Last - Digit) / Base then
               return (Valid => False, Value => 0);
            end if;

            Acc := Acc * Base + Digit;
         end;

         Processed := Processed + 1;
      end loop;

      return (Valid => True, Value => Acc);
   end Natural_Value;

   function Scaled_Natural_Value
     (Text       : String;
      Base       : Number_Base;
      Multiplier : Positive) return Parsed_Natural
   is
      Parsed : constant Parsed_Natural := Natural_Value (Text, Base);
   begin
      if not Parsed.Valid then
         return (Valid => False, Value => 0);
      else
         declare
            Product : constant Long_Long_Integer :=
              Long_Long_Integer (Parsed.Value) * Long_Long_Integer (Multiplier);
         begin
            if Product > Long_Long_Integer (Natural'Last) then
               return (Valid => False, Value => 0);
            else
               return (Valid => True, Value => Natural (Product));
            end if;
         end;
      end if;
   end Scaled_Natural_Value;
end Posix_Tools.Text.Base_Parsing;
