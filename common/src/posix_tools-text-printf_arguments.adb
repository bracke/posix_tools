with Ada.Characters.Handling;
with Ada.Long_Long_Float_Text_IO;
with Ada.Strings.Fixed;
with Posix_Tools.Text.UTF_8;

package body Posix_Tools.Text.Printf_Arguments is
   use Ada.Strings.Unbounded;
   use type Interfaces.Unsigned_64;
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   subtype Unsigned_64 is Interfaces.Unsigned_64;

   function Digit_Value (C : Character) return Natural;
   function Digits_Image (Value : Unsigned_64; Base : Positive; Upper : Boolean) return String;
   function Is_Blank (C : Character) return Boolean;
   function Is_Digit_In (C : Character; Base : Positive) return Boolean;
   --  The largest decimal exponent written out: past every float's range.
   Exponent_Limit : constant := 5_000;

   --  Decimal exponent digits, an optional sign first, saturated past the
   --  limit.
   function Exponent_Value (Text : String) return Long_Long_Integer;
   --  Text_IO's image of a float, d.dddE+eeeee with blanks around it, as
   --  positional decimal digits.
   function Plain_Decimal (Image : String) return String;
   --  Mantissa, digits with an optional '.', times ten to Exponent, written
   --  without an exponent.
   function Positional (Mantissa : String; Exponent : Integer) return String
     with Pre => abs Exponent <= Exponent_Limit;
   function Quoted_Value (Text : String; UTF_8 : Boolean) return Integer_Argument
     with Pre => Text'Length > 0;
   function Sequence_Length (Text : String) return Natural
     with Pre => Text'Length > 0;

   function Digit_Value (C : Character) return Natural is
   begin
      case C is
         when '0' .. '9' =>
            return Character'Pos (C) - Character'Pos ('0');
         when 'a' .. 'f' =>
            return Character'Pos (C) - Character'Pos ('a') + 10;
         when 'A' .. 'F' =>
            return Character'Pos (C) - Character'Pos ('A') + 10;
         when others =>
            return 16;
      end case;
   end Digit_Value;

   function Digits_Image (Value : Unsigned_64; Base : Positive; Upper : Boolean) return String is
      Lower_Digits : constant String := "0123456789abcdef";
      Upper_Digits : constant String := "0123456789ABCDEF";
      Buffer       : String (1 .. 64);
      Next         : Natural := Buffer'Last;
      Rest         : Unsigned_64 := Value;
   begin
      loop
         declare
            Digit : constant Natural := Natural (Rest mod Unsigned_64 (Base));
         begin
            Buffer (Next) := (if Upper then Upper_Digits (Digit + 1) else Lower_Digits (Digit + 1));
         end;
         Rest := Rest / Unsigned_64 (Base);
         exit when Rest = 0;
         Next := Next - 1;
      end loop;
      return Buffer (Next .. Buffer'Last);
   end Digits_Image;

   function Exponent_Value (Text : String) return Long_Long_Integer is
      Negative : constant Boolean := Text'Length > 0 and then Text (Text'First) = '-';
      Value    : Long_Long_Integer := 0;
   begin
      for C of Text loop
         if C in '0' .. '9' then
            Value := Long_Long_Integer'Min (Value * 10 + Long_Long_Integer (Digit_Value (C)), Exponent_Limit + 1);
         end if;
      end loop;
      return (if Negative then -Value else Value);
   end Exponent_Value;

   function First_Character (Text : String; UTF_8 : Boolean) return String is
   begin
      if Text = "" then
         return "";
      elsif UTF_8 then
         return Text (Text'First .. Text'First + Sequence_Length (Text) - 1);
      else
         return Text (Text'First .. Text'First);
      end if;
   end First_Character;

   function Float_Value (Text : String; UTF_8 : Boolean) return Float_Argument is
      I        : Positive := Text'First;
      Negative : Boolean := False;

      function Hexadecimal return Float_Argument;
      function Decimal return Float_Argument;

      --  A decimal constant: digits, a fraction, an exponent that has digits.
      function Decimal return Float_Argument is
         Mantissa_First : constant Positive := I;
         Saw_Digit      : Boolean := False;
         Image          : Unbounded_String;
      begin
         while I <= Text'Last and then Text (I) in '0' .. '9' loop
            Saw_Digit := True;
            I := I + 1;
         end loop;
         Append (Image, (if I = Mantissa_First then "0" else Text (Mantissa_First .. I - 1)));
         if I <= Text'Last and then Text (I) = '.' then
            declare
               Fraction_First : constant Positive := I + 1;
            begin
               I := I + 1;
               while I <= Text'Last and then Text (I) in '0' .. '9' loop
                  Saw_Digit := True;
                  I := I + 1;
               end loop;
               if I > Fraction_First then
                  Append (Image, "." & Text (Fraction_First .. I - 1));
               end if;
            end;
         end if;

         if not Saw_Digit then
            return (Status => Not_Numeric, Image => To_Unbounded_String ("0"));
         end if;

         if I < Text'Last and then Text (I) in 'e' | 'E' then
            declare
               J : Positive := I + 1;
            begin
               if Text (J) in '+' | '-' and then J < Text'Last then
                  J := J + 1;
               end if;
               if Text (J) in '0' .. '9' then
                  while J <= Text'Last and then Text (J) in '0' .. '9' loop
                     J := J + 1;
                  end loop;
                  declare
                     Exponent : constant Long_Long_Integer := Exponent_Value (Text (I + 1 .. J - 1));
                  begin
                     if abs Exponent > Exponent_Limit then
                        return
                          (Status => (if J <= Text'Last then Partially_Converted else Out_Of_Range),
                           Image  => To_Unbounded_String ("0"));
                     end if;
                     Image := To_Unbounded_String (Positional (To_String (Image), Integer (Exponent)));
                  end;
                  I := J;
               end if;
            end;
         end if;

         return
           (Status => (if I <= Text'Last then Partially_Converted else Converted),
            Image  => (if Negative then "-" & Image else Image));
      end Decimal;

      --  0x, hexadecimal digits, a hexadecimal fraction, and a binary
      --  exponent p that has digits; its value goes through Long_Long_Float.
      function Hexadecimal return Float_Argument is
         Value     : Long_Long_Float := 0.0;
         Exponent  : Long_Long_Integer := 0;
         Status    : Conversion_Status := Converted;
      begin
         I := I + 2;
         while I <= Text'Last and then Is_Digit_In (Text (I), 16) loop
            Value := Value * 16.0 + Long_Long_Float (Digit_Value (Text (I)));
            I := I + 1;
         end loop;
         if I <= Text'Last and then Text (I) = '.' then
            I := I + 1;
            while I <= Text'Last and then Is_Digit_In (Text (I), 16) loop
               Value := Value * 16.0 + Long_Long_Float (Digit_Value (Text (I)));
               Exponent := Exponent - 4;
               I := I + 1;
            end loop;
         end if;
         if I < Text'Last and then Text (I) in 'p' | 'P' then
            declare
               J              : Positive := I + 1;
               Exponent_Minus : Boolean := False;
               Written        : Long_Long_Integer := 0;
            begin
               if Text (J) in '+' | '-' and then J < Text'Last then
                  Exponent_Minus := Text (J) = '-';
                  J := J + 1;
               end if;
               if Text (J) in '0' .. '9' then
                  while J <= Text'Last and then Text (J) in '0' .. '9' loop
                     Written := Long_Long_Integer'Min (Written * 10 + Long_Long_Integer (Digit_Value (Text (J))),
                                                       1_000_000);
                     J := J + 1;
                  end loop;
                  Exponent := Exponent + (if Exponent_Minus then -Written else Written);
                  I := J;
               end if;
            end;
         end if;

         if I <= Text'Last then
            Status := Partially_Converted;
         end if;

         declare
            Scaled : Long_Long_Float := Value;
            Buffer : String (1 .. 64);
         begin
            begin
               Scaled := Long_Long_Float'Scaling
                 (Value, Integer (Long_Long_Integer'Max (-100_000, Long_Long_Integer'Min (100_000, Exponent))));
               if not Scaled'Valid or else Scaled > Long_Long_Float'Last then
                  raise Constraint_Error;
               end if;
            exception
               when Constraint_Error =>
                  Scaled := (if Exponent > 0 then Long_Long_Float'Last else 0.0);
                  Status := (if Status = Converted then Out_Of_Range else Status);
            end;
            Ada.Long_Long_Float_Text_IO.Put (Buffer, Scaled, Aft => Long_Long_Float'Digits, Exp => 5);
            return
              (Status => Status,
               Image  => To_Unbounded_String ((if Negative then "-" else "") & Plain_Decimal (Buffer)));
         end;
      end Hexadecimal;
   begin
      if Text = "" then
         return (Status => Converted, Image => To_Unbounded_String ("0"));
      elsif Text (Text'First) in ''' | '"' then
         declare
            Item  : Integer_Argument := Quoted_Value (Text, UTF_8);
            Image : constant String := Signed_Image (Item);
         begin
            return (Status => Item.Status, Image => To_Unbounded_String (Image));
         end;
      end if;

      while I <= Text'Last and then Is_Blank (Text (I)) loop
         I := I + 1;
      end loop;
      if I <= Text'Last and then Text (I) in '+' | '-' then
         Negative := Text (I) = '-';
         I := I + 1;
      end if;

      if I < Text'Last
        and then Text (I) = '0'
        and then Text (I + 1) in 'x' | 'X'
        and then I + 2 <= Text'Last
        and then (Is_Digit_In (Text (I + 2), 16)
                  or else (Text (I + 2) = '.' and then I + 3 <= Text'Last and then Is_Digit_In (Text (I + 3), 16)))
      then
         return Hexadecimal;
      else
         return Decimal;
      end if;
   end Float_Value;

   function Integer_Value (Text : String; UTF_8 : Boolean) return Integer_Argument is
      I      : Positive := Text'First;
      Result : Integer_Argument;
      Base   : Positive := 10;
      Start  : Positive;
   begin
      if Text = "" then
         return Result;
      elsif Text (Text'First) in ''' | '"' then
         return Quoted_Value (Text, UTF_8);
      end if;

      while I <= Text'Last and then Is_Blank (Text (I)) loop
         I := I + 1;
      end loop;
      if I <= Text'Last and then Text (I) in '+' | '-' then
         Result.Negative := Text (I) = '-';
         I := I + 1;
      end if;

      if I < Text'Last
        and then Text (I) = '0'
        and then Text (I + 1) in 'x' | 'X'
        and then I + 2 <= Text'Last
        and then Is_Digit_In (Text (I + 2), 16)
      then
         Base := 16;
         I := I + 2;
      elsif I <= Text'Last and then Text (I) = '0' then
         Base := 8;
      end if;

      Start := I;
      while I <= Text'Last and then Is_Digit_In (Text (I), Base) loop
         declare
            Digit : constant Unsigned_64 := Unsigned_64 (Digit_Value (Text (I)));
         begin
            if Result.Overflow
              or else Result.Magnitude > (Unsigned_64'Last - Digit) / Unsigned_64 (Base)
            then
               Result.Overflow := True;
               Result.Magnitude := Unsigned_64'Last;
            else
               Result.Magnitude := Result.Magnitude * Unsigned_64 (Base) + Digit;
            end if;
         end;
         I := I + 1;
      end loop;

      if I = Start then
         Result.Status := Not_Numeric;
         Result.Negative := False;
      elsif I <= Text'Last then
         Result.Status := Partially_Converted;
      elsif Result.Overflow then
         Result.Status := Out_Of_Range;
      end if;
      return Result;
   end Integer_Value;

   function Is_Blank (C : Character) return Boolean is
     (C = ' ' or else C in Character'Val (9) .. Character'Val (13));

   function Is_Digit_In (C : Character; Base : Positive) return Boolean is
     (Digit_Value (C) < Base);

   function Is_UTF_8_Locale (Name : String) return Boolean is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
      Dot   : constant Natural := Ada.Strings.Fixed.Index (Lower, ".");
      At_Sign : constant Natural := Ada.Strings.Fixed.Index (Lower, "@");
   begin
      if Dot = 0 then
         return False;
      end if;

      declare
         Codeset : constant String :=
           Lower (Dot + 1 .. (if At_Sign > Dot then At_Sign - 1 else Lower'Last));
      begin
         return Codeset = "utf-8" or else Codeset = "utf8";
      end;
   end Is_UTF_8_Locale;

   function Plain_Decimal (Image : String) return String is
      Trimmed : constant String := Ada.Strings.Fixed.Trim (Image, Ada.Strings.Both);
      Mark    : constant Natural := Ada.Strings.Fixed.Index (Trimmed, "E");
   begin
      if Mark = 0 then
         return Trimmed;
      end if;
      return Positional
        (Trimmed (Trimmed'First .. Mark - 1), Integer'Value (Trimmed (Mark + 1 .. Trimmed'Last)));
   end Plain_Decimal;

   function Positional (Mantissa : String; Exponent : Integer) return String is
      Dot        : constant Natural := Ada.Strings.Fixed.Index (Mantissa, ".");
      Whole      : constant String :=
        (if Dot = 0 then Mantissa else Mantissa (Mantissa'First .. Dot - 1));
      Fraction   : constant String := (if Dot = 0 then "" else Mantissa (Dot + 1 .. Mantissa'Last));
      All_Digits : constant String := Whole & Fraction;
      Point      : constant Integer := Whole'Length + Exponent;
   begin
      if Point <= 0 then
         return "0." & [1 .. -Point => '0'] & All_Digits;
      elsif Point >= All_Digits'Length then
         return All_Digits & [1 .. Point - All_Digits'Length => '0'];
      else
         return All_Digits (All_Digits'First .. All_Digits'First + Point - 1)
           & "." & All_Digits (All_Digits'First + Point .. All_Digits'Last);
      end if;
   end Positional;

   --  'c or "c: the codeset value of c, decoded as UTF-8 when it is.
   function Quoted_Value (Text : String; UTF_8 : Boolean) return Integer_Argument is
      Result : Integer_Argument;
   begin
      if Text'Length = 1 then
         Result.Status := Not_Numeric;
         return Result;
      end if;

      declare
         Rest   : constant String := Text (Text'First + 1 .. Text'Last);
         Length : constant Natural := (if UTF_8 then Sequence_Length (Rest) else 1);
      begin
         if Length <= 1 then
            Result.Magnitude := Unsigned_64 (Character'Pos (Rest (Rest'First)));
         else
            declare
               Decoder    : Posix_Tools.Text.UTF_8.Decoder;
               Status     : Posix_Tools.Text.UTF_8.Decode_Status;
               Code_Point : Long_Long_Integer := 0;
            begin
               for J in Rest'First .. Rest'First + Length - 1 loop
                  Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos (Rest (J)), Status, Code_Point);
               end loop;
               Result.Magnitude := Unsigned_64 (Code_Point);
            end;
         end if;
      end;
      return Result;
   end Quoted_Value;

   --  How many bytes the UTF-8 sequence at the start of Text takes: 1 for a
   --  byte that does not start a well-formed sequence.
   function Sequence_Length (Text : String) return Natural is
      Decoder    : Posix_Tools.Text.UTF_8.Decoder;
      Status     : Posix_Tools.Text.UTF_8.Decode_Status;
      Code_Point : Long_Long_Integer;
   begin
      for J in Text'First .. Natural'Min (Text'Last, Text'First + 3) loop
         Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos (Text (J)), Status, Code_Point);
         if Status = Posix_Tools.Text.UTF_8.Complete then
            return J - Text'First + 1;
         elsif Status = Posix_Tools.Text.UTF_8.Invalid then
            return 1;
         end if;
      end loop;
      return 1;
   end Sequence_Length;

   function Signed_Image (Item : in out Integer_Argument) return String is
      Limit : constant Unsigned_64 :=
        (if Item.Negative then 2 ** 63 else 2 ** 63 - 1);
   begin
      if Item.Overflow or else Item.Magnitude > Limit then
         Item.Magnitude := Limit;
         if Item.Status = Converted then
            Item.Status := Out_Of_Range;
         end if;
      end if;
      return
        (if Item.Negative and then Item.Magnitude /= 0 then "-" else "")
        & Digits_Image (Item.Magnitude, 10, False);
   end Signed_Image;

   function Unsigned_Image
     (Item  : in out Integer_Argument;
      Base  : Positive;
      Upper : Boolean) return String
   is
   begin
      if Item.Overflow then
         if Item.Status = Converted then
            Item.Status := Out_Of_Range;
         end if;
         return Digits_Image (Unsigned_64'Last, Base, Upper);
      end if;
      return Digits_Image ((if Item.Negative then -Item.Magnitude else Item.Magnitude), Base, Upper);
   end Unsigned_Image;
end Posix_Tools.Text.Printf_Arguments;
