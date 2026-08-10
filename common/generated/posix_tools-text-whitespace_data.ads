package Posix_Tools.Text.Whitespace_Data is
   Unicode_Version : constant String := "15.1.0";
   Source : constant String := "Unicode Character Database PropList.txt White_Space property";
   License_Reference : constant String := "Unicode License v3";

   type Code_Point_Range is record
      First : Long_Long_Integer;
      Last  : Long_Long_Integer;
   end record;

   type Code_Point_Range_Array is array (Positive range <>) of Code_Point_Range;

   White_Space_Ranges : constant Code_Point_Range_Array :=
     [(16#0009#, 16#000D#),
      (16#0020#, 16#0020#),
      (16#0085#, 16#0085#),
      (16#00A0#, 16#00A0#),
      (16#1680#, 16#1680#),
      (16#2000#, 16#200A#),
      (16#2028#, 16#2029#),
      (16#202F#, 16#202F#),
      (16#205F#, 16#205F#),
      (16#3000#, 16#3000#)];

   function Is_Whitespace (Code_Point : Long_Long_Integer) return Boolean;
end Posix_Tools.Text.Whitespace_Data;
