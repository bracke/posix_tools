with Posix_Tools.Text.Printf_Formats.Number_Images;

package body Posix_Tools.Text.Printf_Formats is
   function Canonical_Decimal (Text : String; Ok : out Boolean) return String is
   begin
      return Posix_Tools.Text.Printf_Formats.Number_Images.Canonical_Decimal (Text, Ok);
   end Canonical_Decimal;

   function Canonical_Unsigned (Text : String; Ok : out Boolean) return String is
   begin
      return Posix_Tools.Text.Printf_Formats.Number_Images.Canonical_Unsigned (Text, Ok);
   end Canonical_Unsigned;

   function Decimal_With_Precision
     (Image         : String;
      Has_Precision : Boolean;
      Precision     : Natural;
      Always_Sign   : Boolean := False;
      Blank_Sign    : Boolean := False) return String
   is
   begin
      return
        Posix_Tools.Text.Printf_Formats.Number_Images.Decimal_With_Precision
          (Image, Has_Precision, Precision, Always_Sign, Blank_Sign);
   end Decimal_With_Precision;

   function Field_Image
     (Text          : String;
      Width         : Natural;
      Left_Justify  : Boolean := False;
      Has_Precision : Boolean := False;
      Precision     : Natural := 0;
      Pad           : Character := ' ') return String
   is
   begin
      return
        Posix_Tools.Text.Printf_Formats.Number_Images.Field_Image
          (Text, Width, Left_Justify, Has_Precision, Precision, Pad);
   end Field_Image;

   function Fixed_Float_Image
     (Text        : String;
      Precision   : Natural;
      Always_Sign : Boolean;
      Blank_Sign  : Boolean;
      Ok          : out Boolean) return String
   is
   begin
      return
        Posix_Tools.Text.Printf_Formats.Number_Images.Fixed_Float_Image
          (Text, Precision, Always_Sign, Blank_Sign, Ok);
   end Fixed_Float_Image;

   function General_Float_Image
     (Text        : String;
      Precision   : Natural;
      Upper       : Boolean;
      Always_Sign : Boolean;
      Blank_Sign  : Boolean;
      Alternate   : Boolean;
      Ok          : out Boolean) return String
   is
   begin
      return
        Posix_Tools.Text.Printf_Formats.Number_Images.General_Float_Image
          (Text, Precision, Upper, Always_Sign, Blank_Sign, Alternate, Ok);
   end General_Float_Image;

   function Localize_Decimal_Number
     (Text                  : String;
      Locale                : String;
      Localize_Radix        : Boolean;
      Localize_Digit_Glyphs : Boolean := True) return String
   is
   begin
      return
        Posix_Tools.Text.Printf_Formats.Number_Images.Localize_Decimal_Number
          (Text, Locale, Localize_Radix, Localize_Digit_Glyphs);
   end Localize_Decimal_Number;

   function Parse_Checked_Signed
     (Text : String;
      Ok   : out Boolean) return Long_Long_Integer
   is
   begin
      return Posix_Tools.Text.Printf_Formats.Number_Images.Parse_Checked_Signed (Text, Ok);
   end Parse_Checked_Signed;

   function Scientific_Float_Image
     (Text        : String;
      Precision   : Natural;
      Upper       : Boolean;
      Always_Sign : Boolean;
      Blank_Sign  : Boolean;
      Alternate   : Boolean;
      Ok          : out Boolean) return String
   is
   begin
      return
        Posix_Tools.Text.Printf_Formats.Number_Images.Scientific_Float_Image
          (Text, Precision, Upper, Always_Sign, Blank_Sign, Alternate, Ok);
   end Scientific_Float_Image;

   function Unsigned_Image
     (Text  : String;
      Base  : Positive;
      Upper : Boolean;
      Ok    : out Boolean) return String
   is
   begin
      return Posix_Tools.Text.Printf_Formats.Number_Images.Unsigned_Image (Text, Base, Upper, Ok);
   end Unsigned_Image;
end Posix_Tools.Text.Printf_Formats;
