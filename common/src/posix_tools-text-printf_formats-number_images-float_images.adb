with Ada.Strings.Unbounded;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Text.Printf_Formats.Number_Images.Float_Images is
   use Ada.Strings.Unbounded;

   function Parse_Float_Exponent
     (Text     : String;
      First    : Positive;
      Exponent : out Integer) return Boolean;

   function Decimal_Exponent_Of (Text : String; Ok : out Boolean) return Integer;

   function Trim_General_Float (Text : String; Alternate : Boolean) return String;

   function Parse_Float_Exponent
     (Text     : String;
      First    : Positive;
      Exponent : out Integer) return Boolean
   is
      Start    : Positive := First;
      Negative : Boolean := False;
   begin
      Exponent := 0;

      if Start > Text'Last then
         return False;
      elsif Text (Start) = '-' or else Text (Start) = '+' then
         Negative := Text (Start) = '-';
         Start := Start + 1;
         if Start > Text'Last then
            return False;
         end if;
      end if;

      declare
         Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
           Posix_Tools.Text.Decimal_Parsing.Natural_In_Range
             (Text (Start .. Text'Last), 0, 9_999_999);
      begin
         if not Parsed.Valid then
            return False;
         end if;
         Exponent := Integer (Parsed.Value);
         if Negative then
            Exponent := -Exponent;
         end if;
         return True;
      end;
   end Parse_Float_Exponent;

   function Decimal_Exponent_Of (Text : String; Ok : out Boolean) return Integer is
      First       : Positive := Text'First;
      Saw_Digit   : Boolean := False;
      Saw_Dot     : Boolean := False;
      Fraction    : Natural := 0;
      Exponent    : Integer := 0;
      Digits_Text : Unbounded_String;
   begin
      Ok := False;
      if Text = "" then
         return 0;
      elsif Text (First) = '-' or else Text (First) = '+' then
         First := First + 1;
         if First > Text'Last then
            return 0;
         end if;
      end if;

      for I in First .. Text'Last loop
         if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I)) then
            Saw_Digit := True;
            Append (Digits_Text, Text (I));
            if Saw_Dot then
               Fraction := Fraction + 1;
            end if;
         elsif Text (I) = '.' and then not Saw_Dot then
            Saw_Dot := True;
         elsif Text (I) in 'e' | 'E' then
            declare
               Parsed_Exponent : Integer;
            begin
               if not Parse_Float_Exponent (Text, I + 1, Parsed_Exponent) then
                  return 0;
               end if;
               Exponent := Parsed_Exponent;
               exit;
            end;
         else
            return 0;
         end if;
      end loop;

      if not Saw_Digit then
         return 0;
      end if;

      declare
         Raw : constant String := To_String (Digits_Text);
      begin
         for I in Raw'Range loop
            if Raw (I) /= '0' then
               Ok := True;
               return Raw'Last - Fraction - I + Exponent;
            end if;
         end loop;
      end;

      Ok := True;
      return 0;
   end Decimal_Exponent_Of;

   function Fixed_Float_Image
     (Text        : String;
      Precision   : Natural;
      Always_Sign : Boolean;
      Blank_Sign  : Boolean;
      Ok          : out Boolean) return String
   is
      First           : Positive := Text'First;
      Negative        : Boolean := False;
      Saw_Digit       : Boolean := False;
      Saw_Dot         : Boolean := False;
      Whole           : Long_Long_Integer := 0;
      Fraction        : Long_Long_Integer := 0;
      Fraction_Digits : Natural := 0;
      Extra_Digit     : Natural := 0;
      Whole_First     : Natural := 0;
      Whole_Last      : Natural := 0;
      Fraction_First  : Natural := 0;
      Fraction_Last   : Natural := 0;
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

      for I in First .. Text'Last loop
         if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I)) then
            Saw_Digit := True;
            if Saw_Dot then
               if Fraction_Digits < Precision then
                  if Fraction_First = 0 then
                     Fraction_First := I;
                  end if;
                  Fraction_Last := I;
                  Fraction_Digits := Fraction_Digits + 1;
               elsif Fraction_Digits = Precision then
                  Extra_Digit := Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Text (I));
                  Fraction_Digits := Fraction_Digits + 1;
               end if;
            else
               if Whole_First = 0 then
                  Whole_First := I;
               end if;
               Whole_Last := I;
            end if;
         elsif Text (I) = '.' and then not Saw_Dot then
            Saw_Dot := True;
         else
            return "";
         end if;
      end loop;

      if not Saw_Digit then
         return "";
      end if;

      if Whole_First /= 0 then
         declare
            Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
              Posix_Tools.Text.Decimal_Parsing.Long_Long_Value
                (Text (Whole_First .. Whole_Last));
         begin
            if not Parsed.Valid or else Parsed.Value < 0 then
               return "";
            end if;
            Whole := Parsed.Value;
         end;
      end if;

      if Fraction_First /= 0 then
         declare
            Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
              Posix_Tools.Text.Decimal_Parsing.Long_Long_Value
                (Text (Fraction_First .. Fraction_Last));
         begin
            if not Parsed.Valid or else Parsed.Value < 0 then
               return "";
            end if;
            Fraction := Parsed.Value;
         end;
      end if;

      while Fraction_Digits < Precision loop
         if Fraction > Long_Long_Integer'Last / 10 then
            return "";
         end if;
         Fraction := Fraction * 10;
         Fraction_Digits := Fraction_Digits + 1;
      end loop;

      if Extra_Digit >= 5 then
         Fraction := Fraction + 1;
         declare
            Scale : Long_Long_Integer := 1;
         begin
            for I in 1 .. Precision loop
               if Scale > Long_Long_Integer'Last / 10 then
                  return "";
               end if;
               Scale := Scale * 10;
            end loop;
            if Precision > 0 and then Fraction >= Scale then
               Fraction := Fraction - Scale;
               if Whole = Long_Long_Integer'Last then
                  return "";
               end if;
               Whole := Whole + 1;
            elsif Precision = 0 then
               if Whole = Long_Long_Integer'Last then
                  return "";
               end if;
               Whole := Whole + 1;
               Fraction := 0;
            end if;
         end;
      end if;

      Ok := True;

      declare
         Whole_Text      : constant String :=
           Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Whole);
         Fraction_Int    : Long_Long_Integer := Fraction;
         Fraction_Buffer : String (1 .. Natural'Max (Precision, 1)) := [others => '0'];
         Sign_Text       : constant String :=
           (if Negative then "-" elsif Always_Sign then "+" elsif Blank_Sign then " " else "");
      begin
         if Precision > 0 then
            for I in reverse 1 .. Precision loop
               Fraction_Buffer (I) :=
                 Posix_Tools.Text.Byte_Classes.ASCII_Digit_Character
                   (Natural (Fraction_Int mod 10));
               Fraction_Int := Fraction_Int / 10;
            end loop;
            return Sign_Text & Whole_Text & "." & Fraction_Buffer (1 .. Precision);
         else
            return Sign_Text & Whole_Text;
         end if;
      end;
   exception
      when Constraint_Error =>
         Ok := False;
         return "";
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
      Effective_Precision : constant Natural := (if Precision = 0 then 1 else Precision);
      Exponent_Ok         : Boolean;
      Decimal_Exponent    : constant Integer := Decimal_Exponent_Of (Text, Exponent_Ok);
   begin
      if not Exponent_Ok then
         Ok := False;
         return "";
      elsif Decimal_Exponent < -4 or else Decimal_Exponent >= Effective_Precision then
         declare
            Image : constant String :=
              Scientific_Float_Image
                (Text, Effective_Precision - 1, Upper, Always_Sign, Blank_Sign, Alternate, Ok);
         begin
            return (if Ok then Trim_General_Float (Image, Alternate) else "");
         end;
      else
         declare
            Fraction_Precision : constant Natural :=
              (if Decimal_Exponent >= Integer (Effective_Precision)
               then 0
               elsif Decimal_Exponent >= 0
               then Effective_Precision - Natural (Decimal_Exponent) - 1
               else Effective_Precision + Natural (-Decimal_Exponent) - 1);
            Image : constant String :=
              Fixed_Float_Image
                (Text, Fraction_Precision, Always_Sign, Blank_Sign, Ok);
         begin
            return (if Ok then Trim_General_Float (Image, Alternate) else "");
         end;
      end if;
   end General_Float_Image;

   function Scientific_Float_Image
     (Text        : String;
      Precision   : Natural;
      Upper       : Boolean;
      Always_Sign : Boolean;
      Blank_Sign  : Boolean;
      Alternate   : Boolean;
      Ok          : out Boolean) return String
   is
      First       : Positive := Text'First;
      Negative    : Boolean := False;
      Saw_Digit   : Boolean := False;
      Saw_Dot     : Boolean := False;
      Fraction    : Natural := 0;
      Exponent    : Integer := 0;
      Digits_Text : Unbounded_String;

      function Exponent_Text (Value : Integer) return String;

      function Exponent_Text (Value : Integer) return String is
         Raw : constant String := Posix_Tools.Text.Numeric_Images.Integer_Image (abs Value);
      begin
         if Raw'Length = 1 then
            return (if Value < 0 then "-0" & Raw else "+0" & Raw);
         else
            return (if Value < 0 then "-" & Raw else "+" & Raw);
         end if;
      end Exponent_Text;
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

      for I in First .. Text'Last loop
         if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I)) then
            Saw_Digit := True;
            Append (Digits_Text, Text (I));
            if Saw_Dot then
               Fraction := Fraction + 1;
            end if;
         elsif Text (I) = '.' and then not Saw_Dot then
            Saw_Dot := True;
         elsif Text (I) in 'e' | 'E' then
            declare
               Parsed_Exponent : Integer;
            begin
               if not Parse_Float_Exponent (Text, I + 1, Parsed_Exponent) then
                  return "";
               end if;
               Exponent := Parsed_Exponent;
               exit;
            end;
         else
            return "";
         end if;
      end loop;

      if not Saw_Digit then
         return "";
      end if;

      declare
         Raw      : constant String := To_String (Digits_Text);
         First_NZ : Natural := 0;
      begin
         for I in Raw'Range loop
            if Raw (I) /= '0' then
               First_NZ := I;
               exit;
            end if;
         end loop;

         if First_NZ = 0 then
            declare
               Fraction_Zeros : constant String (1 .. Natural'Max (Precision, 1)) := [others => '0'];
               Sign_Text      : constant String :=
                 (if Negative then "-" elsif Always_Sign then "+" elsif Blank_Sign then " " else "");
            begin
               Ok := True;
               return Sign_Text
                 & "0"
                 & (if Precision > 0
                    then "." & Fraction_Zeros (1 .. Precision)
                    elsif Alternate
                    then "."
                    else "")
                 & (if Upper then "E+00" else "e+00");
            end;
         else
            declare
               Decimal_Exponent : Integer := Raw'Last - Fraction - First_NZ + Exponent;
               Mantissa_Length  : constant Natural := Precision + 1;
               Mantissa         : String (1 .. Mantissa_Length) := [others => '0'];
               Source_Index     : Natural := First_NZ;
               Round_Digit      : Natural := 0;
               Sign_Text        : constant String :=
                 (if Negative then "-" elsif Always_Sign then "+" elsif Blank_Sign then " " else "");
            begin
               for I in Mantissa'Range loop
                  if Source_Index <= Raw'Last then
                     Mantissa (I) := Raw (Source_Index);
                     Source_Index := Source_Index + 1;
                  end if;
               end loop;

               if Source_Index <= Raw'Last then
                  Round_Digit :=
                    Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value (Raw (Source_Index));
               end if;

               if Round_Digit >= 5 then
                  for I in reverse Mantissa'Range loop
                     if Mantissa (I) < '9' then
                        Mantissa (I) := Character'Val (Character'Pos (Mantissa (I)) + 1);
                        exit;
                     else
                        Mantissa (I) := '0';
                        if I = Mantissa'First then
                           Mantissa (I) := '1';
                           Decimal_Exponent := Decimal_Exponent + 1;
                        end if;
                     end if;
                  end loop;
               end if;

               Ok := True;
               return Sign_Text
                 & Mantissa (Mantissa'First)
                 & (if Precision > 0
                    then "." & Mantissa (Mantissa'First + 1 .. Mantissa'Last)
                    elsif Alternate
                    then "."
                    else "")
                 & (if Upper then "E" else "e")
                 & Exponent_Text (Decimal_Exponent);
            end;
         end if;
      end;
   exception
      when Constraint_Error =>
         Ok := False;
         return "";
   end Scientific_Float_Image;

   function Trim_General_Float (Text : String; Alternate : Boolean) return String is
   begin
      if Alternate then
         return Text;
      end if;

      declare
         Exp_Pos : Natural := 0;
      begin
         for I in Text'Range loop
            if Text (I) in 'e' | 'E' then
               Exp_Pos := I;
               exit;
            end if;
         end loop;

         declare
            Mantissa_First : constant Natural := Text'First;
            Mantissa_Last  : constant Natural := (if Exp_Pos = 0 then Text'Last else Exp_Pos - 1);
            Last           : Natural := Mantissa_Last;
            Dot_Pos        : Natural := 0;
         begin
            for I in Mantissa_First .. Mantissa_Last loop
               if Text (I) = '.' then
                  Dot_Pos := I;
                  exit;
               end if;
            end loop;

            if Dot_Pos = 0 then
               return Text;
            end if;

            while Last > Dot_Pos and then Text (Last) = '0' loop
               Last := Last - 1;
            end loop;
            if Last = Dot_Pos then
               Last := Last - 1;
            end if;

            return Text (Text'First .. Last)
              & (if Exp_Pos = 0 then "" else Text (Exp_Pos .. Text'Last));
         end;
      end;
   end Trim_General_Float;
end Posix_Tools.Text.Printf_Formats.Number_Images.Float_Images;
