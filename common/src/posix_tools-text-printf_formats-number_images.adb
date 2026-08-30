with Ada.Strings.Unbounded;
with I18N.CLDR_Data;
with Posix_Tools.Numbers;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Printf_Formats.Number_Images.Float_Images;

package body Posix_Tools.Text.Printf_Formats.Number_Images is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Numbers.Parse_Status;

   function Canonical_Decimal (Text : String; Ok : out Boolean) return String is
      First    : Positive := Text'First;
      Negative : Boolean := False;
      Parsed   : Posix_Tools.Numbers.Parse_Result;
   begin
      Ok := False;
      if Text = "" then
         return "";
      elsif Text (First) = '-' or else Text (First) = '+' then
         Negative := Text (First) = '-';
         First := First + 1;
         if First > Text'Last then
            return "";
         end if;
      end if;

      Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Text (First .. Text'Last));
      if Parsed.Status /= Posix_Tools.Numbers.Valid then
         return "";
      end if;

      Ok := True;
      declare
         Magnitude : constant String := Posix_Tools.Numbers.Count_Image (Parsed.Value);
      begin
         if Negative and then Parsed.Value /= 0 then
            return "-" & Magnitude;
         else
            return Magnitude;
         end if;
      end;
   end Canonical_Decimal;

   function Canonical_Unsigned (Text : String; Ok : out Boolean) return String is
      First  : Positive := Text'First;
      Parsed : Posix_Tools.Numbers.Parse_Result;
   begin
      Ok := False;
      if Text = "" then
         return "";
      elsif Text (First) = '+' then
         First := First + 1;
         if First > Text'Last then
            return "";
         end if;
      elsif Text (First) = '-' then
         return "";
      end if;

      Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Text (First .. Text'Last));
      if Parsed.Status /= Posix_Tools.Numbers.Valid then
         return "";
      end if;

      Ok := True;
      return Posix_Tools.Numbers.Count_Image (Parsed.Value);
   end Canonical_Unsigned;

   function Decimal_With_Precision
     (Image         : String;
      Has_Precision : Boolean;
      Precision     : Natural;
      Always_Sign   : Boolean := False;
      Blank_Sign    : Boolean := False) return String
   is
      Negative   : constant Boolean := Image'Length > 0 and then Image (Image'First) = '-';
      Magnitude  : constant String :=
        (if Negative then Image (Image'First + 1 .. Image'Last) else Image);
      Zero_Value : constant Boolean :=
        (Magnitude'Length = 1 and then Magnitude (Magnitude'First) = '0');

      function With_Sign (Text : String) return String;

      function With_Sign (Text : String) return String is
      begin
         if Negative then
            return "-" & Text;
         elsif Always_Sign then
            return "+" & Text;
         elsif Blank_Sign then
            return " " & Text;
         else
            return Text;
         end if;
      end With_Sign;
   begin
      if not Has_Precision then
         return With_Sign (Magnitude);
      elsif Precision = 0 and then Zero_Value then
         return With_Sign ("");
      elsif Precision <= Magnitude'Length then
         return With_Sign (Magnitude);
      else
         declare
            Padding : constant String (1 .. Precision - Magnitude'Length) := [others => '0'];
         begin
            return With_Sign (Padding & Magnitude);
         end;
      end if;
   end Decimal_With_Precision;

   function Field_Image
     (Text          : String;
      Width         : Natural;
      Left_Justify  : Boolean := False;
      Has_Precision : Boolean := False;
      Precision     : Natural := 0;
      Pad           : Character := ' ') return String
   is
      Field : constant String :=
        (if Has_Precision and then Precision < Text'Length
         then Text (Text'First .. Text'First + Precision - 1)
         else Text);
   begin
      if Width > Field'Length and then not Left_Justify then
         declare
            Padding : constant String (1 .. Width - Field'Length) := [others => Pad];
         begin
            if Pad = '0'
              and then Field'Length > 0
              and then
                (Field (Field'First) in '-' | '+' | ' '
                 or else (Field'Length > 1 and then Field (Field'First .. Field'First + 1) = "0x")
                 or else (Field'Length > 1 and then Field (Field'First .. Field'First + 1) = "0X"))
            then
               if Field (Field'First) in '-' | '+' | ' ' then
                  return "" & Field (Field'First) & Padding
                    & (if Field'Length > 1 then Field (Field'First + 1 .. Field'Last) else "");
               else
                  return Field (Field'First .. Field'First + 1) & Padding
                    & (if Field'Length > 2 then Field (Field'First + 2 .. Field'Last) else "");
               end if;
            else
               return Padding & Field;
            end if;
         end;
      elsif Width > Field'Length and then Left_Justify then
         declare
            Padding : constant String (1 .. Width - Field'Length) := [others => ' '];
         begin
            return Field & Padding;
         end;
      else
         return Field;
      end if;
   end Field_Image;

   function Fixed_Float_Image
     (Text        : String;
      Precision   : Natural;
      Always_Sign : Boolean;
      Blank_Sign  : Boolean;
      Ok          : out Boolean) return String
   is
   begin
      return Posix_Tools.Text.Printf_Formats.Number_Images.Float_Images.Fixed_Float_Image
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
      return Posix_Tools.Text.Printf_Formats.Number_Images.Float_Images.General_Float_Image
        (Text, Precision, Upper, Always_Sign, Blank_Sign, Alternate, Ok);
   end General_Float_Image;

   function Localize_Decimal_Number
     (Text                  : String;
      Locale                : String;
      Localize_Radix        : Boolean;
      Localize_Digit_Glyphs : Boolean := True) return String
   is
      Radix  : constant String := I18N.CLDR_Data.Decimal_Separator (Locale);
      Plus   : constant String := I18N.CLDR_Data.Number_Plus_Sign (Locale);
      Minus  : constant String := I18N.CLDR_Data.Number_Minus_Sign (Locale);
      Output : Unbounded_String;
   begin
      for I in Text'Range loop
         if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I))
           and then Localize_Digit_Glyphs
         then
            Append (Output, I18N.CLDR_Data.Digit_Text (Locale, Text (I)));
         elsif Text (I) = '.' and then Localize_Radix then
            Append (Output, Radix);
         elsif Text (I) = '+' then
            Append (Output, Plus);
         elsif Text (I) = '-' then
            Append (Output, Minus);
         else
            Append (Output, Text (I));
         end if;
      end loop;

      return To_String (Output);
   end Localize_Decimal_Number;

   function Parse_Checked_Signed
     (Text : String;
      Ok   : out Boolean) return Long_Long_Integer
   is
      Image : constant String := Canonical_Decimal (Text, Ok);
   begin
      if not Ok or else Image = "" then
         Ok := False;
         return 0;
      end if;

      declare
         Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
           Posix_Tools.Text.Decimal_Parsing.Long_Long_Value (Image);
      begin
         if Parsed.Valid then
            return Parsed.Value;
         else
            Ok := False;
            return 0;
         end if;
      end;
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
      return Posix_Tools.Text.Printf_Formats.Number_Images.Float_Images.Scientific_Float_Image
        (Text, Precision, Upper, Always_Sign, Blank_Sign, Alternate, Ok);
   end Scientific_Float_Image;

   function Unsigned_Image
     (Text  : String;
      Base  : Positive;
      Upper : Boolean;
      Ok    : out Boolean) return String
   is
      First  : Positive := Text'First;
      Parsed : Posix_Tools.Numbers.Parse_Result;
   begin
      Ok := False;
      if Text = "" or else Base < 2 or else Base > 16 then
         return "";
      elsif Text (First) = '+' then
         First := First + 1;
         if First > Text'Last then
            return "";
         end if;
      elsif Text (First) = '-' then
         return "";
      end if;

      Parsed := Posix_Tools.Numbers.Parse_Nonnegative (Text (First .. Text'Last));
      if Parsed.Status /= Posix_Tools.Numbers.Valid then
         return "";
      end if;

      Ok := True;
      if Parsed.Value = 0 then
         return "0";
      end if;

      declare
         Buffer : String (1 .. 128);
         Next   : Natural := Buffer'Last;
         Value  : Posix_Tools.Numbers.Count := Parsed.Value;
      begin
         while Value > 0 loop
            declare
               Digit : constant Natural := Natural (Value mod Posix_Tools.Numbers.Count (Base));
            begin
               if Digit <= 9 then
                  Buffer (Next) :=
                    Posix_Tools.Text.Byte_Classes.ASCII_Digit_Character (Digit);
               else
                  Buffer (Next) :=
                    Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (Digit, Upper);
               end if;
               Next := Next - 1;
               Value := Value / Posix_Tools.Numbers.Count (Base);
            end;
         end loop;
         return Buffer (Next + 1 .. Buffer'Last);
      end;
   end Unsigned_Image;
end Posix_Tools.Text.Printf_Formats.Number_Images;
