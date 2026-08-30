package body Posix_Tools.Text.Checksums
  with SPARK_Mode => On
is
   Polynomial : constant Interfaces.Unsigned_32 := 16#04C11DB7#;

   function Advance_CRC
     (CRC  : Interfaces.Unsigned_32;
      Byte : Interfaces.Unsigned_32) return Interfaces.Unsigned_32;

   function Advance_CRC
     (CRC  : Interfaces.Unsigned_32;
      Byte : Interfaces.Unsigned_32) return Interfaces.Unsigned_32
   is
      use type Interfaces.Unsigned_32;
      Result : Interfaces.Unsigned_32 := CRC xor Interfaces.Shift_Left (Byte, 24);
   begin
      for Bit in 1 .. 8 loop
         if (Result and 16#80000000#) /= 0 then
            Result := Interfaces.Shift_Left (Result, 1) xor Polynomial;
         else
            Result := Interfaces.Shift_Left (Result, 1);
         end if;
      end loop;

      return Result;
   end Advance_CRC;

   function POSIX_Cksum_CRC_32 (Text : String) return Interfaces.Unsigned_32 is
      use type Interfaces.Unsigned_32;
      CRC          : Interfaces.Unsigned_32 := 0;
      Length_Value : Natural := Text'Length;
   begin
      for Ch of Text loop
         CRC := Advance_CRC (CRC, Interfaces.Unsigned_32 (Character'Pos (Ch)));
      end loop;

      while Length_Value /= 0 loop
         pragma Loop_Variant (Decreases => Length_Value);

         CRC := Advance_CRC (CRC, Interfaces.Unsigned_32 (Length_Value mod 256));
         Length_Value := Length_Value / 256;
      end loop;

      return not CRC;
   end POSIX_Cksum_CRC_32;
end Posix_Tools.Text.Checksums;
