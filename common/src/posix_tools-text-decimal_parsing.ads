with Posix_Tools.Text.Byte_Classes;

package Posix_Tools.Text.Decimal_Parsing
  with SPARK_Mode => On
is
   type Parsed_Natural is record
      Valid : Boolean := False;
      Value : Natural := 0;
   end record;

   type Parsed_Natural_Field is record
      Valid  : Boolean := False;
      Value  : Natural := 0;
      Last   : Natural := 0;
      Next   : Natural := 0;
      At_End : Boolean := False;
   end record;

   type Parsed_Long_Long is record
      Valid : Boolean := False;
      Value : Long_Long_Integer := 0;
   end record;

   type Parsed_Decimal_Number is record
      Valid    : Boolean := False;
      Mantissa : Long_Long_Integer := 0;
      Scale    : Natural := 0;
   end record;

   function Decimal_In_Range (Text : String; Low, High : Natural) return Boolean
     with Pre => Low <= High;

   function Decimal_Number (Text : String) return Parsed_Decimal_Number
     with
       Post =>
         (if not Decimal_Number'Result.Valid then
            Decimal_Number'Result.Mantissa = 0
            and then Decimal_Number'Result.Scale = 0);

   function Natural_Field (Text : String; First : Positive) return Parsed_Natural_Field
     with
       Pre => Text /= "" and then First in Text'Range,
       Post =>
         (if Natural_Field'Result.Valid then
            Natural_Field'Result.Last in Text'Range
            and then Natural_Field'Result.Value <= Natural'Last
            and then
              (if Natural_Field'Result.At_End then
                 Natural_Field'Result.Next = 0
               else
                 Natural_Field'Result.Next in Text'Range)
          else
            Natural_Field'Result.Value = 0
            and then Natural_Field'Result.Last = 0
            and then Natural_Field'Result.Next = 0
            and then not Natural_Field'Result.At_End);

   function Natural_In_Range (Text : String; Low, High : Natural) return Parsed_Natural
     with
       Pre  => Low <= High,
       Post =>
         (if Natural_In_Range'Result.Valid then
            Natural_In_Range'Result.Value in Low .. High
          else
            Natural_In_Range'Result.Value = 0);

   function Is_Decimal_Text (Text : String) return Boolean is
     (Text /= ""
      and then
        (for all I in Text'Range =>
           Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I))))
     with
       Post =>
         Is_Decimal_Text'Result =
           (Text /= ""
            and then
              (for all I in Text'Range =>
                 Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I))));

   function Long_Long_Value (Text : String) return Parsed_Long_Long
     with
       Post =>
         (if not Long_Long_Value'Result.Valid then Long_Long_Value'Result.Value = 0);

   function Looks_Like_Negative_Number (Text : String) return Boolean is
     (Text'Length > 1
      and then Text (Text'First) = '-'
      and then
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (Text'First + 1))
         or else Text (Text'First + 1) = '.'))
     with
       Post =>
         Looks_Like_Negative_Number'Result =
           (Text'Length > 1
            and then Text (Text'First) = '-'
            and then
              (Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (Text'First + 1))
               or else Text (Text'First + 1) = '.'));

   function Long_Long_Addition_Overflows
     (Left, Right : Long_Long_Integer) return Boolean
   is
     ((Right > 0 and then Left > Long_Long_Integer'Last - Right)
      or else (Right < 0 and then Left < Long_Long_Integer'First - Right))
   with
     Post =>
       Long_Long_Addition_Overflows'Result =
         ((Right > 0 and then Left > Long_Long_Integer'Last - Right)
          or else (Right < 0 and then Left < Long_Long_Integer'First - Right));

   function Natural_Value (Text : String) return Parsed_Natural
     with
       Post =>
         (if not Natural_Value'Result.Valid then Natural_Value'Result.Value = 0);

   function Power_10 (Count : Natural) return Long_Long_Integer
     with
       Post =>
         Power_10'Result = 0
         or else Power_10'Result in 1 .. Long_Long_Integer'Last;

   function Scale_By_Power_10
     (Value : Long_Long_Integer;
      Count : Natural) return Parsed_Long_Long
     with
       Post =>
         (if not Scale_By_Power_10'Result.Valid then Scale_By_Power_10'Result.Value = 0);

   function Scale_Decimal_Number
     (Item : Parsed_Decimal_Number;
      Target_Scale : Natural) return Parsed_Long_Long
     with
       Pre =>
         Item.Valid
         and then Target_Scale >= Item.Scale,
       Post =>
         (if not Scale_Decimal_Number'Result.Valid then
            Scale_Decimal_Number'Result.Value = 0);

   function Four_Digit_Value (Text : String) return Natural
     with
       Pre =>
         Text'Length = 4
         and then Text'First <= Positive'Last - 3
         and then Is_Decimal_Text (Text),
       Post => Four_Digit_Value'Result <= 9_999;

   function Two_Digit_Value (Text : String) return Natural
     with
       Pre =>
         Text'Length = 2
         and then Is_Decimal_Text (Text),
       Post => Two_Digit_Value'Result <= 99;
end Posix_Tools.Text.Decimal_Parsing;
