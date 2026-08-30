with Interfaces;

package Posix_Tools.Text.OD_Formats
  with SPARK_Mode => On
is
   type Address_Base is (No_Address, Octal_Address, Decimal_Address, Hex_Address);

   type Parsed_Address_Base is record
      Valid : Boolean := False;
      Base  : Address_Base := Octal_Address;
   end record;

   type Parsed_Type_Size is record
      Valid : Boolean;
      Size  : Positive;
   end record;

   type Parsed_Offset_Count is record
      Valid : Boolean := False;
      Value : Natural := 0;
   end record;

   type Dump_Format_Kind is
     (Named_Byte, Character_Byte, Signed_Integer, Floating_Point, Octal_Integer, Unsigned_Integer, Hex_Integer);

   type Parsed_Dump_Format_Item is record
      Valid      : Boolean := False;
      Kind       : Dump_Format_Kind := Octal_Integer;
      Size       : Positive := 1;
      Next_Index : Positive := 1;
      At_End     : Boolean := False;
   end record;

   function Character_Field (Item : Character) return String
     with Post => Character_Field'Result'Length in 4 .. 5;

   function Address_Base_For (Spec : String) return Parsed_Address_Base
     with Post =>
       (if Address_Base_For'Result.Valid then
          ((Spec = "n" and then Address_Base_For'Result.Base = No_Address)
           or else (Spec = "o" and then Address_Base_For'Result.Base = Octal_Address)
           or else (Spec = "d" and then Address_Base_For'Result.Base = Decimal_Address)
           or else (Spec = "x" and then Address_Base_For'Result.Base = Hex_Address))
        else
          (Spec /= "n" and then Spec /= "o" and then Spec /= "d" and then Spec /= "x"
           and then Address_Base_For'Result.Base = Octal_Address));

   function Address_Image (Base : Address_Base; Value : Natural) return String
     with Post =>
       (if Base = No_Address then
          Address_Image'Result'Length = 0
        elsif Base in Octal_Address | Hex_Address then
          Address_Image'Result'Length = 7
        else
          Address_Image'Result'Length in 1 .. 20);

   function Decimal_U64_Image (Value : Interfaces.Unsigned_64) return String
     with Post =>
       Decimal_U64_Image'Result'Length in 1 .. 20
       and then
         (for all I in Decimal_U64_Image'Result'Range =>
            Decimal_U64_Image'Result (I) in '0' .. '9');

   function Dump_Format_Item (Spec : String; Index : Positive) return Parsed_Dump_Format_Item
     with Pre => Spec /= "" and then Index in Spec'Range;

   function Hex_U64_Image (Value : Interfaces.Unsigned_64; Width : Positive) return String
     with Post =>
       Hex_U64_Image'Result'Length = Width
       and then
         (for all I in Hex_U64_Image'Result'Range =>
            Hex_U64_Image'Result (I) in '0' .. '9' | 'a' .. 'f');

   function Is_Address_Base_Spec (Spec : String) return Boolean
     with Post =>
       Is_Address_Base_Spec'Result =
         (Spec = "n" or else Spec = "o" or else Spec = "d" or else Spec = "x");

   function Is_Shorthand_Format_Option (Option : Character) return Boolean
     with Post =>
       Is_Shorthand_Format_Option'Result =
         (Option = 'a' or else Option = 'b' or else Option = 'c'
          or else Option = 'd' or else Option = 'o'
          or else Option = 's' or else Option = 'x');

   function Named_Field (Item : Character) return String
     with Post => Named_Field'Result'Length = 4;

   function Octal_U64_Image (Value : Interfaces.Unsigned_64; Width : Positive) return String
     with Post =>
       Octal_U64_Image'Result'Length = Width
       and then
         (for all I in Octal_U64_Image'Result'Range =>
            Octal_U64_Image'Result (I) in '0' .. '7');

   function Offset_Count (Text : String; Allow_Suffix : Boolean) return Parsed_Offset_Count
     with Post =>
       (if not Offset_Count'Result.Valid then Offset_Count'Result.Value = 0);

   function Shorthand_Format_Item (Option : Character) return Parsed_Dump_Format_Item
     with Post =>
       (if not Shorthand_Format_Item'Result.Valid then
          Shorthand_Format_Item'Result.Kind = Octal_Integer
          and then Shorthand_Format_Item'Result.Size = 1);

   function Signed_Image (Value : Interfaces.Unsigned_64; Size : Positive) return String
     with Pre => Size in 1 .. 8;

   function Type_Size (Marker : Character; Default : Positive) return Parsed_Type_Size
     with Post =>
       (if Type_Size'Result.Valid then
          ((Marker = '0' and then Type_Size'Result.Size = Default)
           or else (Marker = 'C' and then Type_Size'Result.Size = 1)
           or else (Marker = 'S' and then Type_Size'Result.Size = 2)
           or else (Marker = 'I' and then Type_Size'Result.Size = 4)
           or else (Marker = 'L' and then Type_Size'Result.Size = 8))
        else
          (Marker not in '0' | 'C' | 'S' | 'I' | 'L'
           and then Type_Size'Result.Size = Default));

   function Unit_Value (Text : String; First : Positive; Size : Positive) return Interfaces.Unsigned_64
     with
       Pre =>
         Text /= ""
         and then First in Text'Range
         and then Size in 1 .. 8;
end Posix_Tools.Text.OD_Formats;
