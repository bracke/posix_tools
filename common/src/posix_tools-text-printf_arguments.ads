with Ada.Strings.Unbounded;
with Interfaces;

--  The argument operands of printf's conversions, read as XCU printf reads
--  them: a numeric argument is a C constant -- optional blanks and sign, then
--  decimal, octal after a leading 0, or hexadecimal after 0x or 0X -- or, when
--  it starts with a single or double quote, the codeset value of the
--  character after the quote.
package Posix_Tools.Text.Printf_Arguments is
   --  How much of an argument was a number. Not_Numeric and
   --  Partially_Converted keep the value of the leading part that was one
   --  (zero when none was); Out_Of_Range keeps the nearest value there is.
   type Conversion_Status is (Converted, Not_Numeric, Partially_Converted, Out_Of_Range);

   type Integer_Argument is record
      Status    : Conversion_Status := Converted;
      Negative  : Boolean := False;
      --  The magnitude, saturated at the largest Unsigned_64.
      Magnitude : Interfaces.Unsigned_64 := 0;
      --  The magnitude did not fit Unsigned_64.
      Overflow  : Boolean := False;
   end record;

   type Float_Argument is record
      Status : Conversion_Status := Converted;
      --  The value as decimal text: an optional '-', digits, an optional
      --  fraction and an optional exponent, as the float images read it.
      Image  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Text as an integer constant; with UTF_8 a quoted character is decoded
   --  as UTF-8, otherwise its first byte is its value.
   function Integer_Value (Text : String; UTF_8 : Boolean) return Integer_Argument;

   --  Text as a floating constant: decimal, or hexadecimal with an optional
   --  binary exponent, or a quoted character.
   function Float_Value (Text : String; UTF_8 : Boolean) return Float_Argument;

   --  The value for %d and %i as decimal text, the sign included. A value
   --  past Long_Long_Integer is the nearest one, and Item.Status says so.
   function Signed_Image (Item : in out Integer_Argument) return String;

   --  The value for %u, %o, %x and %X in Base (8, 10 or 16): a negative
   --  value wraps modulo 2**64, as strtoumax gives it. A magnitude past
   --  Unsigned_64 is the largest one, and Item.Status says so.
   function Unsigned_Image
     (Item  : in out Integer_Argument;
      Base  : Positive;
      Upper : Boolean) return String
     with Pre => Base in 8 | 10 | 16;

   --  The first character of Text for %c: its first byte, or with UTF_8 the
   --  whole UTF-8 sequence it starts with when that is well formed.
   function First_Character (Text : String; UTF_8 : Boolean) return String;

   --  Does the locale name a UTF-8 codeset (its codeset part is UTF-8 or
   --  utf8, in any case)?
   function Is_UTF_8_Locale (Name : String) return Boolean;
end Posix_Tools.Text.Printf_Arguments;
