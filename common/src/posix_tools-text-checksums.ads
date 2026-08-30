with Interfaces;

package Posix_Tools.Text.Checksums
  with SPARK_Mode => On
is
   function POSIX_Cksum_CRC_32 (Text : String) return Interfaces.Unsigned_32;
end Posix_Tools.Text.Checksums;
