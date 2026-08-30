package body Posix_Tools.Text.Hex_Digests
  with SPARK_Mode => On
is
   function Is_SHA256_Digest (Text : String) return Boolean is
   begin
      if Text'Length /= 64 then
         return False;
      end if;

      for I in Text'Range loop
         if not Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit (Text (I)) then
            return False;
         end if;
         pragma Loop_Invariant
           (for all J in Text'First .. I =>
              Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit (Text (J)));
      end loop;

      return True;
   end Is_SHA256_Digest;
end Posix_Tools.Text.Hex_Digests;
