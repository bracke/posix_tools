with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Hex_Digests;

package body Posix_Tools.Text.Checksum_Lines
  with SPARK_Mode => On
is
   function Lower_Hex (Text : String) return String is
      Result : String := Text;
   begin
      for Ch of Result loop
         if Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper_Hex_Digit (Ch) then
            Ch := Posix_Tools.Text.Byte_Classes.To_ASCII_Lower (Ch);
         end if;
      end loop;

      return Result;
   end Lower_Hex;

   function SHA256_Check_Line_Info (Line : String) return SHA256_Check_Line is
      Name_First : Natural;
   begin
      if Line'Length < 67 then
         return (Valid => False, Name_First => 0);
      end if;

      if not Posix_Tools.Text.Hex_Digests.Is_SHA256_Digest
        (Line (Line'First .. Line'First + 63))
      then
         return (Valid => False, Name_First => 0);
      end if;

      if Line (Line'First + 64) /= ' ' then
         return (Valid => False, Name_First => 0);
      end if;

      Name_First := Line'First + 65;
      if Name_First <= Line'Last and then Line (Name_First) in ' ' | '*' then
         Name_First := Name_First + 1;
      end if;

      if Name_First > Line'Last then
         return (Valid => False, Name_First => 0);
      end if;

      return (Valid => True, Name_First => Name_First);
   end SHA256_Check_Line_Info;
end Posix_Tools.Text.Checksum_Lines;
