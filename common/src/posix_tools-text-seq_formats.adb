with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Text.Seq_Formats
  with SPARK_Mode => On
is
   function Invalid return Parsed_Seq_Format
     with
       Post =>
         not Invalid'Result.Valid
         and then Invalid'Result.Percent_Index = 0
         and then Invalid'Result.Conversion_Index = 0
         and then Invalid'Result.Conversion = Character'Val (0)
         and then Invalid'Result.Width = 0
         and then not Invalid'Result.Has_Precision
         and then Invalid'Result.Precision = 0;

   function Invalid return Parsed_Seq_Format is
   begin
      return
        (Valid            => False,
         Percent_Index    => 0,
         Conversion_Index => 0,
         Conversion       => Character'Val (0),
         Width            => 0,
         Has_Precision    => False,
         Precision        => 0);
   end Invalid;

   function Parse_Seq_Format (Format : String) return Parsed_Seq_Format
   is
      Percent_Index : Natural := 0;
      Width         : Natural := 0;
      Has_Precision : Boolean := False;
      Precision     : Natural := 0;
   begin
      for I in Format'Range loop
         pragma Loop_Invariant (Percent_Index = 0 or else Percent_Index in Format'Range);

         if Format (I) = '%' then
            if I < Format'Last and then Format (I + 1) = '%' then
               null;
            elsif Percent_Index = 0 then
               Percent_Index := I;
            else
               return Invalid;
            end if;
         end if;
      end loop;

      if Percent_Index = 0 or else Percent_Index >= Format'Last then
         return Invalid;
      end if;

      declare
         I : Natural := Percent_Index + 1;
      begin
         pragma Assert (I in Format'Range);
         pragma Assert (Percent_Index < I);

         if Format (I) = '0' then
            if I >= Format'Last then
               return Invalid;
            end if;
            I := I + 1;
            pragma Assert (Percent_Index < I);
         end if;

         if I <= Format'Last
           and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Format (I))
         then
            declare
               Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural_Field :=
                 Posix_Tools.Text.Decimal_Parsing.Natural_Field (Format, I);
            begin
               if not Parsed.Valid
                 or else Parsed.At_End
                 or else Parsed.Next <= Percent_Index
               then
                  return Invalid;
               end if;

               Width := Parsed.Value;
               I := Parsed.Next;
               pragma Assert (Percent_Index < I);
            end;
         end if;

         if I <= Format'Last and then Format (I) = '.' then
            Has_Precision := True;
            if I >= Format'Last then
               return Invalid;
            end if;
            I := I + 1;
            pragma Assert (Percent_Index < I);

            if I <= Format'Last
              and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Format (I))
            then
               declare
                  Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural_Field :=
                    Posix_Tools.Text.Decimal_Parsing.Natural_Field (Format, I);
               begin
                  if not Parsed.Valid
                    or else Parsed.At_End
                    or else Parsed.Next <= Percent_Index
                  then
                     return Invalid;
                  end if;

                  Precision := Parsed.Value;
                  I := Parsed.Next;
                  pragma Assert (Percent_Index < I);
               end;
            end if;
         end if;

         if I > Format'Last or else Format (I) not in 'f' | 'F' | 'g' | 'G' then
            return Invalid;
         end if;

         pragma Assert (Percent_Index < I);
         return
           (Valid            => True,
            Percent_Index    => Percent_Index,
            Conversion_Index => I,
            Conversion       => Format (I),
            Width            => Width,
            Has_Precision    => Has_Precision,
            Precision        => Precision);
      end;
   end Parse_Seq_Format;

   function Fixed_Decimal
     (Item          : Long_Long_Integer;
      Decimal_Scale : Natural;
      Precision     : Natural) return String
     with SPARK_Mode => Off
   is
      Factor         : constant Long_Long_Integer :=
        Posix_Tools.Text.Decimal_Parsing.Power_10 (Decimal_Scale);
      Abs_Item       : constant Long_Long_Integer := abs Item;
      Whole          : constant String :=
        Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Abs_Item / Factor);
      Fraction_Value : Long_Long_Integer := Abs_Item mod Factor;
   begin
      if Precision = 0 then
         return (if Item < 0 then "-" & Whole else Whole);
      end if;

      declare
         Fraction_Text : String (1 .. Natural'Max (Decimal_Scale, Precision)) := [others => '0'];
      begin
         for I in reverse 1 .. Decimal_Scale loop
            Fraction_Text (I) :=
              Posix_Tools.Text.Byte_Classes.ASCII_Digit_Character
                (Natural (Fraction_Value mod 10));
            Fraction_Value := Fraction_Value / 10;
         end loop;

         if Precision > Decimal_Scale then
            for I in Decimal_Scale + 1 .. Precision loop
               Fraction_Text (I) := '0';
            end loop;
         end if;

         if Item < 0 then
            return "-" & Whole & "." & Fraction_Text (1 .. Precision);
         else
            return Whole & "." & Fraction_Text (1 .. Precision);
         end if;
      end;
   end Fixed_Decimal;

   function Pad_Zero (Text : String; Width : Natural) return String is
   begin
      if Text'Length >= Width then
         return Text;
      elsif Text'Length > 0 and then Text (Text'First) = '-' then
         if Text'Length = 1 then
            return "-" & [1 .. Width - Text'Length => '0'];
         else
            return "-" & [1 .. Width - Text'Length => '0'] & Text (Text'First + 1 .. Text'Last);
         end if;
      else
         return [1 .. Width - Text'Length => '0'] & Text;
      end if;
   end Pad_Zero;

   function Trimmed_Decimal
     (Item          : Long_Long_Integer;
      Decimal_Scale : Natural) return String
     with SPARK_Mode => Off
   is
      Factor         : constant Long_Long_Integer :=
        Posix_Tools.Text.Decimal_Parsing.Power_10 (Decimal_Scale);
      Abs_Item       : constant Long_Long_Integer := abs Item;
      Whole          : constant String :=
        Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Abs_Item / Factor);
      Fraction_Value : Long_Long_Integer := Abs_Item mod Factor;
      Fraction       : String (1 .. Decimal_Scale);
      Last           : Natural := Fraction'Last;
   begin
      if Decimal_Scale = 0 then
         return Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Item);
      end if;

      for I in reverse Fraction'Range loop
         Fraction (I) :=
           Posix_Tools.Text.Byte_Classes.ASCII_Digit_Character
             (Natural (Fraction_Value mod 10));
         Fraction_Value := Fraction_Value / 10;
      end loop;

      while Last > Fraction'First and then Fraction (Last) = '0' loop
         Last := Last - 1;
      end loop;

      if Item < 0 then
         return "-" & Whole & "." & Fraction (Fraction'First .. Last);
      else
         return Whole & "." & Fraction (Fraction'First .. Last);
      end if;
   end Trimmed_Decimal;

   function Valid_Render_Scale (Scale : Natural) return Boolean is
   begin
      return Scale <= 18;
   end Valid_Render_Scale;
end Posix_Tools.Text.Seq_Formats;
