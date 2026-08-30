with Posix_Tools.Text.Byte_Classes;

package body Posix_Tools.Text.Numeric_Images
  with SPARK_Mode => On
is
   function Trim_Image (Raw : String) return String is
   begin
      if Raw'Length > 1 and then Raw (Raw'First) = ' ' then
         return Raw (Raw'First + 1 .. Raw'Last);
      else
         return Raw;
      end if;
   end Trim_Image;

   function Fixed_Decimal_Image (Value : Natural; Width : Positive) return String is
      Result : String (1 .. Width) := [others => '0'];
      Work   : Natural := Value;
   begin
      for I in reverse Result'Range loop
         pragma Loop_Invariant
           (for all J in Result'Range => Result (J) in '0' .. '9');

         Result (I) :=
           Posix_Tools.Text.Byte_Classes.ASCII_Digit_Character (Work mod 10);
         Work := Work / 10;
      end loop;

      return Result;
   end Fixed_Decimal_Image;

   function Fixed_Hex_Image (Value : Natural; Width : Positive) return String is
      Result : String (1 .. Width) := [others => '0'];
      Work   : Natural := Value;
   begin
      for I in reverse Result'Range loop
         pragma Loop_Invariant
           (for all J in Result'Range => Result (J) in '0' .. '9' | 'a' .. 'f');

         Result (I) :=
           Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (Work mod 16);
         Work := Work / 16;
      end loop;

      return Result;
   end Fixed_Hex_Image;

   function Fixed_Octal_Image (Value : Natural; Width : Positive) return String is
      Result : String (1 .. Width) := [others => '0'];
      Work   : Natural := Value;
   begin
      for I in reverse Result'Range loop
         pragma Loop_Invariant
           (for all J in Result'Range => Result (J) in '0' .. '7');

         Result (I) :=
           Posix_Tools.Text.Byte_Classes.ASCII_Octal_Digit_Character (Work mod 8);
         Work := Work / 8;
      end loop;

      return Result;
   end Fixed_Octal_Image;

   function Four_Digit_Image (Value : Natural) return String is
   begin
      return Fixed_Decimal_Image (Value, 4);
   end Four_Digit_Image;

   function Integer_Image (Value : Integer) return String is
   begin
      return Trim_Image (Integer'Image (Value));
   end Integer_Image;

   function Long_Long_Integer_Image (Value : Long_Long_Integer) return String is
   begin
      return Trim_Image (Long_Long_Integer'Image (Value));
   end Long_Long_Integer_Image;

   function Natural_Image (Value : Natural) return String is
   begin
      return Trim_Image (Natural'Image (Value));
   end Natural_Image;

   function Space_Two_Image (Value : Natural) return String is
   begin
      if Value < 10 then
         return " " & Posix_Tools.Text.Byte_Classes.ASCII_Digit_Character (Value);
      else
         return Two_Digit_Image (Value);
      end if;
   end Space_Two_Image;

   function Three_Digit_Image (Value : Natural) return String is
   begin
      return Fixed_Decimal_Image (Value, 3);
   end Three_Digit_Image;

   function Two_Digit_Image (Value : Natural) return String is
   begin
      return Fixed_Decimal_Image (Value, 2);
   end Two_Digit_Image;
end Posix_Tools.Text.Numeric_Images;
