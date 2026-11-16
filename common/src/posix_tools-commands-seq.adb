with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with I18N.Number_Format;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Numeric_Images;
with Posix_Tools.Text.Seq_Formats;

package body Posix_Tools.Commands.Seq is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;

   LF : constant Character := Character'Val (10);

   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Operands  : String_Vectors.Vector;
      First     : Long_Long_Integer := 1;
      Increment : Long_Long_Integer := 1;
      Last      : Long_Long_Integer := 0;
      Scale     : Natural := 0;
      Separator : Unbounded_String := To_Unbounded_String ("" & LF);
      Equal_Width : Boolean := False;
      Format_Text : Unbounded_String;
      Has_Format  : Boolean := False;
      Parsed_Format : Posix_Tools.Text.Seq_Formats.Parsed_Seq_Format;
      Format_Prefix : Unbounded_String;
      Format_Suffix : Unbounded_String;
      Radix_Text : Unbounded_String;
      Plus_Text  : Unbounded_String;
      Minus_Text : Unbounded_String;
      type Digit_Text_Array is array (Character range '0' .. '9') of Unbounded_String;
      Digit_Texts : Digit_Text_Array;
      ASCII_Numeric_Locale : Boolean := False;

      function Localize_Decimal_Number (Text : String) return String is
         Output  : Unbounded_String;
      begin
         if ASCII_Numeric_Locale then
            return Text;
         end if;

         for I in Text'Range loop
            if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I)) then
               Append (Output, Digit_Texts (Text (I)));
            elsif Text (I) = '.' then
               Append (Output, Radix_Text);
            elsif Text (I) = '+' then
               Append (Output, Plus_Text);
            elsif Text (I) = '-' then
               Append (Output, Minus_Text);
            else
               Append (Output, Text (I));
            end if;
         end loop;

         return To_String (Output);
      end Localize_Decimal_Number;

      function Default_Image (Item : Long_Long_Integer; Width : Natural := 0) return String is
      begin
         return Localize_Decimal_Number
           (Posix_Tools.Text.Seq_Formats.Pad_Zero
              (Posix_Tools.Text.Seq_Formats.Trimmed_Decimal (Item, Scale), Width));
      end Default_Image;

      function Format_Image (Item : Long_Long_Integer) return String is
      begin
         if not Parsed_Format.Valid then
            return Default_Image (Item);
         end if;

         declare
            Precision : constant Natural :=
              (if Parsed_Format.Has_Precision then Parsed_Format.Precision else Scale);
            Number : constant String :=
              (if not Parsed_Format.Has_Precision and then Parsed_Format.Conversion in 'g' | 'G'
               then Default_Image (Item, Parsed_Format.Width)
               else
                 Localize_Decimal_Number
                   (Posix_Tools.Text.Seq_Formats.Pad_Zero
                      (Posix_Tools.Text.Seq_Formats.Fixed_Decimal
                         (Item, Scale, Precision),
                       Parsed_Format.Width)));
         begin
            return To_String (Format_Prefix) & Number & To_String (Format_Suffix);
         end;
      end Format_Image;

      procedure Invalid (Text : String) is
      begin
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Text);
      end Invalid;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      declare
         I : Positive := 1;
      begin
         while I <= Context.Argument_Count loop
            declare
               Arg : constant String := Context.Argument (I);
            begin
               if Arg = "--" then
                  I := I + 1;
                  while I <= Context.Argument_Count loop
                     Operands.Append (Context.Argument (I));
                     I := I + 1;
                  end loop;
               elsif Arg = "-w" then
                  Equal_Width := True;
                  I := I + 1;
               elsif Arg = "-s" or else Arg = "-f" then
                  if I >= Context.Argument_Count then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Option_Argument, Arg);
                     return;
                  end if;
                  if Arg = "-s" then
                     Separator := To_Unbounded_String (Context.Argument (I + 1));
                  else
                     Format_Text := To_Unbounded_String (Context.Argument (I + 1));
                     Has_Format := True;
                  end if;
                  I := I + 2;
               elsif Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-s" then
                  Separator := To_Unbounded_String (Arg (Arg'First + 2 .. Arg'Last));
                  I := I + 1;
               elsif Arg'Length > 2 and then Arg (Arg'First .. Arg'First + 1) = "-f" then
                  Format_Text := To_Unbounded_String (Arg (Arg'First + 2 .. Arg'Last));
                  Has_Format := True;
                  I := I + 1;
               elsif Arg'Length > 1
                 and then Arg (Arg'First) = '-'
                 and then not Posix_Tools.Text.Decimal_Parsing.Looks_Like_Negative_Number (Arg)
               then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, Unknown_Option,
                     Posix_Tools.Commands.Helpers.Unknown_Option_Subject (Arg, "fsw"));
                  return;
               else
                  Operands.Append (Arg);
                  I := I + 1;
               end if;
            end;
         end loop;
      end;

      if Operands.Length not in 1 .. 3 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand_Count);
         return;
      end if;

      declare
         Parsed : array (1 .. 3) of Posix_Tools.Text.Decimal_Parsing.Parsed_Decimal_Number;
      begin
         for I in 1 .. Natural (Operands.Length) loop
            Parsed (I) := Posix_Tools.Text.Decimal_Parsing.Decimal_Number (Operands.Element (I));
            if not Parsed (I).Valid then
               Invalid (Operands.Element (I));
               return;
            end if;
            Scale := Natural'Max (Scale, Parsed (I).Scale);
         end loop;

         if Operands.Length = 1 then
            Parsed (3) := Parsed (1);
            Parsed (2) := (Valid => True, Mantissa => 1, Scale => 0);
            Parsed (1) := (Valid => True, Mantissa => 1, Scale => 0);
         elsif Operands.Length = 2 then
            Parsed (3) := Parsed (2);
            Parsed (2) := (Valid => True, Mantissa => 1, Scale => 0);
         end if;

         declare
            Parsed_First : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
              Posix_Tools.Text.Decimal_Parsing.Scale_Decimal_Number (Parsed (1), Scale);
            Parsed_Increment : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
              Posix_Tools.Text.Decimal_Parsing.Scale_Decimal_Number (Parsed (2), Scale);
            Parsed_Last : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Long_Long :=
              Posix_Tools.Text.Decimal_Parsing.Scale_Decimal_Number (Parsed (3), Scale);
         begin
            if not Parsed_First.Valid
              or else not Parsed_Increment.Valid
              or else not Parsed_Last.Valid
            then
               Invalid (Operands.Element (1));
               return;
            end if;
            First := Parsed_First.Value;
            Increment := Parsed_Increment.Value;
            Last := Parsed_Last.Value;
         end;
      end;

      if Increment = 0 then
         Invalid (Operands.Element ((if Operands.Length = 3 then 2 else 1)));
         return;
      elsif not Posix_Tools.Text.Seq_Formats.Valid_Render_Scale (Scale) then
         Invalid (Operands.Element (1));
         return;
      end if;

      declare
         Locale : constant String :=
           Context.Category_Locale (Posix_Tools.Commands.Contexts.Numeric);
      begin
         Radix_Text := To_Unbounded_String
           (I18N.Number_Format.Decimal_Separator (Locale));
         Plus_Text := To_Unbounded_String (I18N.Number_Format.Plus_Sign (Locale));
         Minus_Text := To_Unbounded_String (I18N.Number_Format.Minus_Sign (Locale));
         ASCII_Numeric_Locale :=
           To_String (Radix_Text) = "."
           and then To_String (Plus_Text) = "+"
           and then To_String (Minus_Text) = "-";
         for Digit in Digit_Texts'Range loop
            Digit_Texts (Digit) := To_Unbounded_String
              (I18N.Number_Format.Digit_Text (Locale, Digit));
            ASCII_Numeric_Locale := ASCII_Numeric_Locale
              and then To_String (Digit_Texts (Digit)) = "" & Digit;
         end loop;
      end;

      if Has_Format then
         declare
            Format : constant String := To_String (Format_Text);
         begin
            Parsed_Format := Posix_Tools.Text.Seq_Formats.Parse_Seq_Format (Format);
            if Parsed_Format.Valid then
               Format_Prefix := To_Unbounded_String
                 (Format (Format'First .. Parsed_Format.Percent_Index - 1));
               if Parsed_Format.Conversion_Index < Format'Last then
                  Format_Suffix := To_Unbounded_String
                    (Format (Parsed_Format.Conversion_Index + 1 .. Format'Last));
               end if;
            end if;
         end;
      end if;

      declare
         Current : Long_Long_Integer := First;
         First_Output : Boolean := True;
         Width : Natural := 0;
         Separator_Text : constant String := To_String (Separator);
         Simple_Integer_Output : constant Boolean :=
           ASCII_Numeric_Locale
           and then Scale = 0
           and then not Has_Format
           and then not Equal_Width;
         Output : Posix_Tools.Commands.Helpers.Output_Buffer;

         procedure Flush;
         procedure Queue (Text : String);

         procedure Flush is
         begin
            Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
         end Flush;

         procedure Queue (Text : String) is
         begin
            Posix_Tools.Commands.Helpers.Buffered_Put
              (Output, Context, Text);
         end Queue;
      begin
         if Equal_Width and then not Has_Format then
            Width := Natural'Max (Default_Image (First)'Length, Default_Image (Last)'Length);
         end if;

         while (Increment > 0 and then Current <= Last) or else (Increment < 0 and then Current >= Last) loop
            if not First_Output then
               Queue (Separator_Text);
               exit when Context.Output_Failed;
            end if;
            Queue
              ((if Simple_Integer_Output
                then Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                  (Current)
                elsif Has_Format
                then Format_Image (Current)
                else Default_Image (Current, Width)));
            First_Output := False;
            exit when Context.Output_Failed;
            if Posix_Tools.Text.Decimal_Parsing.Long_Long_Addition_Overflows
              (Current, Increment)
            then
               exit;
            end if;
            Current := Current + Increment;
         end loop;
         --  An empty sequence, such as seq 2 1, writes nothing at all.
         if not First_Output and then not Context.Output_Failed then
            Queue ("" & LF);
         end if;
         Flush;
      end;

      Posix_Tools.Commands.Helpers.Finish (Context, Result);
   end Run;
end Posix_Tools.Commands.Seq;
