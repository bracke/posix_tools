package Posix_Tools.Text.File_Modes
  with SPARK_Mode => On
is
   subtype Mode_Bit is Positive
     with Static_Predicate =>
       Mode_Bit in 8#4000# | 8#2000# | 8#1000# | 8#400# | 8#200#
       | 8#100# | 8#040# | 8#020# | 8#010# | 8#004# | 8#002# | 8#001#;

   type Permission_Mode_Status is
     (Invalid_Permission_Mode,
      Octal_Permission_Mode,
      Symbolic_Permission_Mode);

   type Parsed_Permission_Mode is record
      Status    : Permission_Mode_Status := Invalid_Permission_Mode;
      Mode      : Natural := 0;
      Match_All : Boolean := False;
   end record;

   type Symbolic_Permission_Bits_Result is record
      Valid : Boolean := False;
      Bits  : Natural := 0;
   end record;

   type Symbolic_Permission_Operation_Result is record
      Valid : Boolean := False;
      Mode  : Natural := 0;
   end record;

   type Symbolic_Mode_Result is record
      Valid : Boolean := False;
      Mode  : Natural := 0;
   end record;

   function Has_Mode_Bit (Value : Natural; Bit : Positive) return Boolean
     with Post =>
       Has_Mode_Bit'Result = ((Value / Bit) mod 2 = 1);

   function Has_Any_Mode_Bit (Mode, Mask : Natural) return Boolean;

   function Has_All_Mode_Bits (Mode, Mask : Natural) return Boolean;

   function Set_Mode_Bit (Value : Natural; Bit : Mode_Bit) return Natural
     with Pre => Value <= 8#7777#,
          Post =>
            Set_Mode_Bit'Result <= 8#7777#
            and then
              (if Has_Mode_Bit (Value, Bit) then Set_Mode_Bit'Result = Value
               else Set_Mode_Bit'Result = Value + Bit);

   function Clear_Mode_Bit (Value : Natural; Bit : Mode_Bit) return Natural
     with Pre => Value <= 8#7777#,
          Post =>
            Clear_Mode_Bit'Result <= Value
            and then
              (if Has_Mode_Bit (Value, Bit) then Clear_Mode_Bit'Result = Value - Bit
               else Clear_Mode_Bit'Result = Value);

   function Clear_Mode_Mask (Value, Mask : Natural) return Natural
     with Pre => Value <= 8#7777#,
          Post => Clear_Mode_Mask'Result <= Value;

   function Set_Mode_Mask (Value, Mask : Natural) return Natural
     with Pre => Value <= 8#7777#,
          Post => Set_Mode_Mask'Result <= 8#7777#;

   function Symbolic_Permission_Bits
     (Who_Mask, Source_Mode : Natural;
      Permission : Character) return Symbolic_Permission_Bits_Result
     with Pre => Who_Mask <= 8#7777# and Source_Mode <= 8#7777#,
          Post =>
            Symbolic_Permission_Bits'Result.Bits <= 8#7777#
            and then
              (if not Symbolic_Permission_Bits'Result.Valid then
                 Symbolic_Permission_Bits'Result.Bits = 0);

   function Apply_Symbolic_Permission_Operation
     (Current_Mode, Who_Mask, Permission_Mask : Natural;
      Operation : Character) return Symbolic_Permission_Operation_Result
     with Pre =>
            Current_Mode <= 8#7777#
            and Who_Mask <= 8#7777#
            and Permission_Mask <= 8#7777#,
          Post =>
            Apply_Symbolic_Permission_Operation'Result.Mode <= 8#7777#
            and then
              (if not Apply_Symbolic_Permission_Operation'Result.Valid then
                 Apply_Symbolic_Permission_Operation'Result.Mode = Current_Mode);

   function Apply_Symbolic_Mode
     (Text : String;
      Base : Natural) return Symbolic_Mode_Result
     with Pre =>
            Base <= 8#7777#
            and Text'First in Positive
            and Text'Last < Positive'Last,
          Post =>
            Apply_Symbolic_Mode'Result.Mode <= 8#7777#
            and then
              (if not Apply_Symbolic_Mode'Result.Valid then
                 Apply_Symbolic_Mode'Result.Mode = Base);

   function Symbolic_Who_Mask (Mask : Natural; Who : Character) return Natural
     with Pre => Mask <= 8#7777#,
          Post => Symbolic_Who_Mask'Result <= 8#7777#;

   function Parse_Find_Permission_Mode (Text : String) return Parsed_Permission_Mode
     with
       Pre =>
         Text'First in Positive
         and then Text'First < Positive'Last
         and then Text'Last < Positive'Last,
       Post =>
       (case Parse_Find_Permission_Mode'Result.Status is
          when Invalid_Permission_Mode =>
            Parse_Find_Permission_Mode'Result.Mode = 0,
          when Octal_Permission_Mode | Symbolic_Permission_Mode =>
            Parse_Find_Permission_Mode'Result.Mode <= 8#7777#);

   function Parse_Permission_Mode (Text : String) return Parsed_Permission_Mode
     with Post =>
       (case Parse_Permission_Mode'Result.Status is
          when Invalid_Permission_Mode =>
            Parse_Permission_Mode'Result.Mode = 0,
          when Octal_Permission_Mode =>
            Parse_Permission_Mode'Result.Mode <= 8#7777#,
          when Symbolic_Permission_Mode =>
            Parse_Permission_Mode'Result.Mode = 0);

   function Permission_Matches
     (Actual, Expected : Natural;
      Match_All : Boolean) return Boolean
     with Post =>
       Permission_Matches'Result =
         (if Match_All then Has_All_Mode_Bits (Actual, Expected)
          else Actual = Expected);

   function Four_Digit_Octal_Image (Value : Natural) return String
     with Post =>
       Four_Digit_Octal_Image'Result'Length = 4
       and then
         (for all I in Four_Digit_Octal_Image'Result'Range =>
            Four_Digit_Octal_Image'Result (I) in '0' .. '7');
end Posix_Tools.Text.File_Modes;
