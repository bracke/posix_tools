with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Base_Parsing;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Text.OD_Formats
  with SPARK_Mode => On
is
   function Address_Base_For (Spec : String) return Parsed_Address_Base is
   begin
      if Spec = "n" then
         return (Valid => True, Base => No_Address);
      elsif Spec = "o" then
         return (Valid => True, Base => Octal_Address);
      elsif Spec = "d" then
         return (Valid => True, Base => Decimal_Address);
      elsif Spec = "x" then
         return (Valid => True, Base => Hex_Address);
      else
         return (Valid => False, Base => Octal_Address);
      end if;
   end Address_Base_For;

   function Address_Image (Base : Address_Base; Value : Natural) return String is
   begin
      case Base is
         when No_Address =>
            return "";
         when Octal_Address =>
            return Posix_Tools.Text.Numeric_Images.Fixed_Octal_Image (Value, 7);
         when Decimal_Address =>
            return Decimal_U64_Image (Interfaces.Unsigned_64 (Value));
         when Hex_Address =>
            return Posix_Tools.Text.Numeric_Images.Fixed_Hex_Image (Value, 7);
      end case;
   end Address_Image;

   function Character_Field (Item : Character) return String is
   begin
      case Item is
         when Character'Val (0) =>
            return "  \\0";
         when Character'Val (8) =>
            return "  \\b";
         when Character'Val (9) =>
            return "  \\t";
         when Character'Val (10) =>
            return "  \\n";
         when Character'Val (12) =>
            return "  \\f";
         when Character'Val (13) =>
            return "  \\r";
         when ' ' .. '~' =>
            return "   " & Item;
         when others =>
            return " " & Octal_U64_Image (Interfaces.Unsigned_64 (Character'Pos (Item)), 3);
      end case;
   end Character_Field;

   function Decimal_Digit_Character (Value : Interfaces.Unsigned_64) return Character
     with Post => Decimal_Digit_Character'Result in '0' .. '9';

   function Decimal_Digit_Character (Value : Interfaces.Unsigned_64) return Character is
      use type Interfaces.Unsigned_64;
      Digit : constant Interfaces.Unsigned_64 := Value mod 10;
   begin
      if Digit = 0 then
         return '0';
      elsif Digit = 1 then
         return '1';
      elsif Digit = 2 then
         return '2';
      elsif Digit = 3 then
         return '3';
      elsif Digit = 4 then
         return '4';
      elsif Digit = 5 then
         return '5';
      elsif Digit = 6 then
         return '6';
      elsif Digit = 7 then
         return '7';
      elsif Digit = 8 then
         return '8';
      else
         return '9';
      end if;
   end Decimal_Digit_Character;

   function Fixed_Decimal_U64_Image (Value : Interfaces.Unsigned_64) return String
     with Post =>
       Fixed_Decimal_U64_Image'Result'Length = 20
       and then Fixed_Decimal_U64_Image'Result'First = 1
       and then Fixed_Decimal_U64_Image'Result'Last = 20
       and then
         (for all I in Fixed_Decimal_U64_Image'Result'Range =>
            Fixed_Decimal_U64_Image'Result (I) in '0' .. '9');

   function Decimal_U64_Image (Value : Interfaces.Unsigned_64) return String is
      use type Interfaces.Unsigned_64;
      Full : constant String := Fixed_Decimal_U64_Image (Value);
   begin
      if Value < 10 then
         return Full (20 .. 20);
      elsif Value < 100 then
         return Full (19 .. 20);
      elsif Value < 1_000 then
         return Full (18 .. 20);
      elsif Value < 10_000 then
         return Full (17 .. 20);
      elsif Value < 100_000 then
         return Full (16 .. 20);
      elsif Value < 1_000_000 then
         return Full (15 .. 20);
      elsif Value < 10_000_000 then
         return Full (14 .. 20);
      elsif Value < 100_000_000 then
         return Full (13 .. 20);
      elsif Value < 1_000_000_000 then
         return Full (12 .. 20);
      elsif Value < 10_000_000_000 then
         return Full (11 .. 20);
      elsif Value < 100_000_000_000 then
         return Full (10 .. 20);
      elsif Value < 1_000_000_000_000 then
         return Full (9 .. 20);
      elsif Value < 10_000_000_000_000 then
         return Full (8 .. 20);
      elsif Value < 100_000_000_000_000 then
         return Full (7 .. 20);
      elsif Value < 1_000_000_000_000_000 then
         return Full (6 .. 20);
      elsif Value < 10_000_000_000_000_000 then
         return Full (5 .. 20);
      elsif Value < 100_000_000_000_000_000 then
         return Full (4 .. 20);
      elsif Value < 1_000_000_000_000_000_000 then
         return Full (3 .. 20);
      elsif Value < 10_000_000_000_000_000_000 then
         return Full (2 .. 20);
      else
         return Full;
      end if;
   end Decimal_U64_Image;

   function Dump_Format_Item (Spec : String; Index : Positive) return Parsed_Dump_Format_Item
   is
      function Valid_After
        (Kind : Dump_Format_Kind;
         Size : Positive;
         Last : Positive) return Parsed_Dump_Format_Item
        with Pre => Last in Spec'Range and then Size in 1 | 2 | 4 | 8;

      function Valid_After
        (Kind : Dump_Format_Kind;
         Size : Positive;
         Last : Positive) return Parsed_Dump_Format_Item
      is
      begin
         if Last = Spec'Last then
            return
              (Valid      => True,
               Kind       => Kind,
               Size       => Size,
               Next_Index => Index,
               At_End     => True);
         else
            return
              (Valid      => True,
               Kind       => Kind,
               Size       => Size,
               Next_Index => Last + 1,
               At_End     => False);
         end if;
      end Valid_After;

      Kind         : Dump_Format_Kind;
      Default_Size : Positive := 1;
      Size         : Positive := 1;
   begin
      case Spec (Index) is
         when 'a' =>
            return Valid_After (Named_Byte, 1, Index);
         when 'c' =>
            return Valid_After (Character_Byte, 1, Index);
         when 'd' =>
            Kind := Signed_Integer;
            Default_Size := 2;
         when 'f' =>
            Kind := Floating_Point;
            Default_Size := 8;
         when 'o' =>
            Kind := Octal_Integer;
            Default_Size := 2;
         when 'u' =>
            Kind := Unsigned_Integer;
            Default_Size := 2;
         when 'x' =>
            Kind := Hex_Integer;
            Default_Size := 2;
         when others =>
            return (Valid => False, Kind => Octal_Integer, Size => 1, Next_Index => Index, At_End => False);
      end case;

      if Index = Spec'Last then
         return Valid_After (Kind, Default_Size, Index);
      end if;

      declare
         Cursor : constant Positive := Index + 1;
      begin
         if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Spec (Cursor)) then
            declare
               Last_Digit : Positive := Cursor;
            begin
               while Last_Digit < Spec'Last
                 and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Spec (Last_Digit + 1))
               loop
                  pragma Loop_Invariant (Last_Digit in Cursor .. Spec'Last - 1);
                  pragma Loop_Variant (Increases => Last_Digit);

                  Last_Digit := Last_Digit + 1;
               end loop;

               declare
                  Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
                    Posix_Tools.Text.Decimal_Parsing.Natural_Value (Spec (Cursor .. Last_Digit));
               begin
                  if not Parsed.Valid or else Parsed.Value not in 1 | 2 | 4 | 8 then
                     return
                       (Valid => False, Kind => Octal_Integer, Size => 1, Next_Index => Index, At_End => False);
                  end if;
                  Size := Positive (Parsed.Value);
                  if Kind = Floating_Point and then Size not in 4 | 8 then
                     return
                       (Valid => False, Kind => Octal_Integer, Size => 1, Next_Index => Index, At_End => False);
                  end if;
                  return Valid_After (Kind, Size, Last_Digit);
               end;
            end;
         elsif Spec (Cursor) in 'C' | 'S' | 'I' | 'L' | 'F' | 'D' then
            if Kind = Floating_Point then
               case Spec (Cursor) is
                  when 'F' =>
                     return Valid_After (Kind, 4, Cursor);
                  when 'D' | 'L' =>
                     return Valid_After (Kind, 8, Cursor);
                  when others =>
                     return
                       (Valid => False, Kind => Octal_Integer, Size => 1, Next_Index => Index, At_End => False);
               end case;
            else
               declare
                  Parsed : constant Parsed_Type_Size := Type_Size (Spec (Cursor), Default_Size);
               begin
                  if not Parsed.Valid then
                     return
                       (Valid => False, Kind => Octal_Integer, Size => 1, Next_Index => Index, At_End => False);
                  end if;
                  return Valid_After (Kind, Parsed.Size, Cursor);
               end;
            end if;
         else
            return Valid_After (Kind, Default_Size, Index);
         end if;
      end;
   end Dump_Format_Item;

   function Fixed_Decimal_U64_Image (Value : Interfaces.Unsigned_64) return String is
      use type Interfaces.Unsigned_64;
      Result : String (1 .. 20) := [others => '0'];
      Work   : Interfaces.Unsigned_64 := Value;
   begin
      for I in reverse Result'Range loop
         pragma Loop_Invariant
           (for all J in Result'Range => Result (J) in '0' .. '9');

         Result (I) := Decimal_Digit_Character (Work);
         Work := Work / 10;
      end loop;

      return Result;
   end Fixed_Decimal_U64_Image;

   function Hex_U64_Image (Value : Interfaces.Unsigned_64; Width : Positive) return String is
      use type Interfaces.Unsigned_64;
      Result : String (1 .. Width) := [others => '0'];
      Work   : Interfaces.Unsigned_64 := Value;
   begin
      for I in reverse Result'Range loop
         pragma Loop_Invariant
           (for all J in Result'Range => Result (J) in '0' .. '9' | 'a' .. 'f');
         pragma Assert (Work mod 16 <= 15);

         Result (I) :=
           Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (Natural (Work mod 16));
         Work := Work / 16;
      end loop;

      return Result;
   end Hex_U64_Image;

   function Is_Address_Base_Spec (Spec : String) return Boolean is
   begin
      return Spec = "n" or else Spec = "o" or else Spec = "d" or else Spec = "x";
   end Is_Address_Base_Spec;

   function Is_Shorthand_Format_Option (Option : Character) return Boolean is
   begin
      return Option in 'a' | 'b' | 'c' | 'd' | 'o' | 's' | 'x';
   end Is_Shorthand_Format_Option;

   function Named_Field (Item : Character) return String is
      Names : constant array (Natural range 0 .. 127) of String (1 .. 3) :=
        [0 => "nul", 1 => "soh", 2 => "stx", 3 => "etx", 4 => "eot", 5 => "enq", 6 => "ack", 7 => "bel",
         8 => " bs", 9 => " ht", 10 => " nl", 11 => " vt", 12 => " ff", 13 => " cr", 14 => " so", 15 => " si",
         16 => "dle", 17 => "dc1", 18 => "dc2", 19 => "dc3", 20 => "dc4", 21 => "nak", 22 => "syn",
         23 => "etb", 24 => "can", 25 => " em", 26 => "sub", 27 => "esc", 28 => " fs", 29 => " gs",
         30 => " rs", 31 => " us", 32 => " sp", 127 => "del", others => "   "];
      Value : constant Natural := Character'Pos (Item) mod 128;
   begin
      if Value in 33 .. 126 then
         return "   " & Character'Val (Value);
      else
         return " " & Names (Value);
      end if;
   end Named_Field;

   function Octal_U64_Image (Value : Interfaces.Unsigned_64; Width : Positive) return String is
      use type Interfaces.Unsigned_64;
      Result : String (1 .. Width) := [others => '0'];
      Work   : Interfaces.Unsigned_64 := Value;
   begin
      for I in reverse Result'Range loop
         pragma Loop_Invariant
           (for all J in Result'Range => Result (J) in '0' .. '7');
         pragma Assert (Work mod 8 <= 7);

         Result (I) :=
           Posix_Tools.Text.Byte_Classes.ASCII_Octal_Digit_Character (Natural (Work mod 8));
         Work := Work / 8;
      end loop;

      return Result;
   end Octal_U64_Image;

   function Offset_Count (Text : String; Allow_Suffix : Boolean) return Parsed_Offset_Count
   is
   begin
      if Text = "" then
         return (Valid => False, Value => 0);
      end if;

      declare
         Base       : Posix_Tools.Text.Base_Parsing.Number_Base := 10;
         Index      : Positive := Text'First;
         Last_Index : Natural := Text'Last;
         Multiplier : Positive := 1;
      begin
         if Text'Length > 2
           and then Text (Text'First) = '0'
           and then Text (Text'First + 1) in 'x' | 'X'
         then
            Base := 16;
            Index := Text'First + 2;
         elsif Text'Length > 1 and then Text (Text'First) = '0' then
            Base := 8;
         end if;

         if Allow_Suffix and then Base /= 16 and then Last_Index >= Index then
            case Text (Last_Index) is
               when 'b' =>
                  Multiplier := 512;
                  Last_Index := Last_Index - 1;
               when 'k' =>
                  Multiplier := 1_024;
                  Last_Index := Last_Index - 1;
               when 'm' =>
                  Multiplier := 1_048_576;
                  Last_Index := Last_Index - 1;
               when others =>
                  null;
            end case;
         end if;

         if Index > Last_Index then
            return (Valid => False, Value => 0);
         end if;

         declare
            Parsed : constant Posix_Tools.Text.Base_Parsing.Parsed_Natural :=
              Posix_Tools.Text.Base_Parsing.Scaled_Natural_Value
                (Text (Index .. Last_Index), Base, Multiplier);
         begin
            if not Parsed.Valid then
               return (Valid => False, Value => 0);
            else
               return (Valid => True, Value => Parsed.Value);
            end if;
         end;
      end;
   end Offset_Count;

   function Shorthand_Format_Item (Option : Character) return Parsed_Dump_Format_Item is
   begin
      case Option is
         when 'a' =>
            return (Valid => True, Kind => Named_Byte, Size => 1, Next_Index => 1, At_End => True);
         when 'b' =>
            return (Valid => True, Kind => Octal_Integer, Size => 1, Next_Index => 1, At_End => True);
         when 'c' =>
            return (Valid => True, Kind => Character_Byte, Size => 1, Next_Index => 1, At_End => True);
         when 'd' =>
            return (Valid => True, Kind => Unsigned_Integer, Size => 2, Next_Index => 1, At_End => True);
         when 'o' =>
            return (Valid => True, Kind => Octal_Integer, Size => 2, Next_Index => 1, At_End => True);
         when 's' =>
            return (Valid => True, Kind => Signed_Integer, Size => 2, Next_Index => 1, At_End => True);
         when 'x' =>
            return (Valid => True, Kind => Hex_Integer, Size => 2, Next_Index => 1, At_End => True);
         when others =>
            return (Valid => False, Kind => Octal_Integer, Size => 1, Next_Index => 1, At_End => False);
      end case;
   end Shorthand_Format_Item;

   function Signed_Image (Value : Interfaces.Unsigned_64; Size : Positive) return String is
      use type Interfaces.Unsigned_64;
      Bits     : constant Natural := Size * 8;
      Sign_Bit : constant Interfaces.Unsigned_64 := Interfaces.Shift_Left (1, Bits - 1);
   begin
      if (Value and Sign_Bit) = 0 then
         return Decimal_U64_Image (Value);
      elsif Size = 8 then
         return "-" & Decimal_U64_Image (Interfaces.Unsigned_64'Last - Value + 1);
      else
         return "-" & Decimal_U64_Image (Interfaces.Shift_Left (1, Bits) - Value);
      end if;
   end Signed_Image;

   function Type_Size (Marker : Character; Default : Positive) return Parsed_Type_Size is
   begin
      case Marker is
         when '0' =>
            return (Valid => True, Size => Default);
         when 'C' =>
            return (Valid => True, Size => 1);
         when 'S' =>
            return (Valid => True, Size => 2);
         when 'I' =>
            return (Valid => True, Size => 4);
         when 'L' =>
            return (Valid => True, Size => 8);
         when others =>
            return (Valid => False, Size => Default);
      end case;
   end Type_Size;

   function Unit_Value (Text : String; First : Positive; Size : Positive) return Interfaces.Unsigned_64 is
      use type Interfaces.Unsigned_64;
      Value : Interfaces.Unsigned_64 := 0;
   begin
      for Offset in 0 .. Size - 1 loop
         pragma Loop_Invariant (Offset in 0 .. 7);

         declare
            Index : constant Natural :=
              (if Offset <= Text'Last - First then First + Offset else 0);
            Byte  : constant Interfaces.Unsigned_64 :=
              (if Index /= 0 then Interfaces.Unsigned_64 (Character'Pos (Text (Index))) else 0);
         begin
            Value := Value or Interfaces.Shift_Left (Byte, Offset * 8);
         end;
      end loop;

      return Value;
   end Unit_Value;
end Posix_Tools.Text.OD_Formats;
