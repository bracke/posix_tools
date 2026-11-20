with Ada.Streams;

--  WHATWG-compatible label resolution and immutable native decoding tables.
package Posix_Tools.Commands.Rg.Encodings is
   type Encoding_Mode is
     (Automatic_Encoding,
      No_Encoding,
      UTF_8_Encoding,
      UTF_16_Encoding,
      UTF_16LE_Encoding,
      UTF_16BE_Encoding,
      IBM866_Encoding,
      ISO_8859_2_Encoding,
      ISO_8859_3_Encoding,
      ISO_8859_4_Encoding,
      ISO_8859_5_Encoding,
      ISO_8859_6_Encoding,
      ISO_8859_7_Encoding,
      ISO_8859_8_Encoding,
      ISO_8859_10_Encoding,
      ISO_8859_13_Encoding,
      ISO_8859_14_Encoding,
      ISO_8859_15_Encoding,
      ISO_8859_16_Encoding,
      KOI8_R_Encoding,
      KOI8_U_Encoding,
      Macintosh_Encoding,
      Windows_874_Encoding,
      Windows_1250_Encoding,
      Windows_1251_Encoding,
      Windows_1252_Encoding,
      Windows_1253_Encoding,
      Windows_1254_Encoding,
      Windows_1255_Encoding,
      Windows_1256_Encoding,
      Windows_1257_Encoding,
      Windows_1258_Encoding,
      X_Mac_Cyrillic_Encoding,
      GBK_Encoding,
      GB18030_Encoding,
      Big5_Encoding,
      EUC_JP_Encoding,
      ISO_2022_JP_Encoding,
      Shift_JIS_Encoding,
      EUC_KR_Encoding,
      Replacement_Encoding,
      X_User_Defined_Encoding);

   type Single_Byte_Kind is
     (IBM866_Kind,
      ISO_8859_2_Kind,
      ISO_8859_3_Kind,
      ISO_8859_4_Kind,
      ISO_8859_5_Kind,
      ISO_8859_6_Kind,
      ISO_8859_7_Kind,
      ISO_8859_8_Kind,
      ISO_8859_10_Kind,
      ISO_8859_13_Kind,
      ISO_8859_14_Kind,
      ISO_8859_15_Kind,
      ISO_8859_16_Kind,
      KOI8_R_Kind,
      KOI8_U_Kind,
      Macintosh_Kind,
      Windows_874_Kind,
      Windows_1250_Kind,
      Windows_1251_Kind,
      Windows_1252_Kind,
      Windows_1253_Kind,
      Windows_1254_Kind,
      Windows_1255_Kind,
      Windows_1256_Kind,
      Windows_1257_Kind,
      Windows_1258_Kind,
      X_Mac_Cyrillic_Kind);

   subtype Code_Point is Long_Long_Integer range -1 .. 16#10FFFF#;
   Invalid_Code_Point : constant Code_Point := -1;

   function Resolve_Label
     (Label : String; Mode : out Encoding_Mode) return Boolean;
   function Decode_Single_Byte
     (Kind : Single_Byte_Kind; Value : Ada.Streams.Stream_Element) return Code_Point;
   function Decode_Big5 (Pointer : Natural) return Code_Point;
   function Decode_EUC_KR (Pointer : Natural) return Code_Point;
   function Decode_GB18030_Two_Byte (Pointer : Natural) return Code_Point;
   function Decode_GB18030_Range (Pointer : Natural) return Code_Point;
   function Decode_JIS0208 (Pointer : Natural) return Code_Point;
   function Decode_JIS0212 (Pointer : Natural) return Code_Point;
end Posix_Tools.Commands.Rg.Encodings;
