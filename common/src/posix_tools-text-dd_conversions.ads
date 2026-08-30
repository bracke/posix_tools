with Posix_Tools.Numbers;

package Posix_Tools.Text.DD_Conversions
  with SPARK_Mode => On
is
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Numbers.Parse_Status;

   type Case_Conversion_Kind is
     (No_Case_Conversion, Uppercase_Conversion, Lowercase_Conversion);

   type Block_Conversion_Kind is
     (No_Block_Conversion, Block_Conversion, Unblock_Conversion);

   type Character_Set_Conversion_Kind is
     (No_Character_Set_Conversion, To_Ascii_Conversion, To_Ebcdic_Conversion);

   type Parsed_Conversions is record
      Valid : Boolean := False;
      Case_Conversion : Case_Conversion_Kind := No_Case_Conversion;
      Block_Conversion : Block_Conversion_Kind := No_Block_Conversion;
      Character_Set_Conversion : Character_Set_Conversion_Kind := No_Character_Set_Conversion;
      Swap_Adjacent_Bytes : Boolean := False;
      Sync_Conversion : Boolean := False;
      No_Truncate_Output : Boolean := False;
      Continue_After_Read_Error : Boolean := False;
   end record;

   function Parse_Conversions (Value : String) return Parsed_Conversions;

   function Parse_Nonnegative (Value : String) return Posix_Tools.Numbers.Parse_Result
     with
       Post =>
         (if Parse_Nonnegative'Result.Status /= Posix_Tools.Numbers.Valid then
            Parse_Nonnegative'Result.Value = 0);
end Posix_Tools.Text.DD_Conversions;
