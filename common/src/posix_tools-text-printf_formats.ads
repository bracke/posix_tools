--  Floating-point conversions are rendered by the Float_Images child.
package Posix_Tools.Text.Printf_Formats is
   function Decimal_With_Precision
     (Image         : String;
      Has_Precision : Boolean;
      Precision     : Natural;
      Always_Sign   : Boolean := False;
      Blank_Sign    : Boolean := False) return String;

   function Field_Image
     (Text          : String;
      Width         : Natural;
      Left_Justify  : Boolean := False;
      Has_Precision : Boolean := False;
      Precision     : Natural := 0;
      Pad           : Character := ' ') return String;

   function Localize_Decimal_Number
     (Text                  : String;
      Locale                : String;
      Localize_Radix        : Boolean;
      Localize_Digit_Glyphs : Boolean := True) return String;

   function Unsigned_Image
     (Text  : String;
      Base  : Positive;
      Upper : Boolean;
      Ok    : out Boolean) return String;
end Posix_Tools.Text.Printf_Formats;
