with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with I18N.CLDR_Data;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Seq_Formats;

package body Posix_Tools.Commands.Seq is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;

   LF : constant Character := Character'Val (10);

   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   procedure Set_Success
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
   begin
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Set_Success;

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

      function Numeric_Locale return String is
         LC_All     : constant String := Context.Environment_Value ("LC_ALL");
         LC_Numeric : constant String := Context.Environment_Value ("LC_NUMERIC");
         Lang       : constant String := Context.Environment_Value ("LANG");
      begin
         if LC_All /= "" then
            return LC_All;
         elsif LC_Numeric /= "" then
            return LC_Numeric;
         elsif Lang /= "" then
            return Lang;
         else
            return Context.Effective_Locale;
         end if;
      end Numeric_Locale;

      function Localize_Decimal_Number (Text : String) return String is
         Locale  : constant String := Numeric_Locale;
         Radix   : constant String := I18N.CLDR_Data.Decimal_Separator (Locale);
         Plus    : constant String := I18N.CLDR_Data.Number_Plus_Sign (Locale);
         Minus   : constant String := I18N.CLDR_Data.Number_Minus_Sign (Locale);
         Output  : Unbounded_String;
      begin
         for I in Text'Range loop
            if Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I)) then
               Append (Output, I18N.CLDR_Data.Digit_Text (Locale, Text (I)));
            elsif Text (I) = '.' then
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

      function Default_Image (Item : Long_Long_Integer; Width : Natural := 0) return String is
      begin
         return Localize_Decimal_Number
           (Posix_Tools.Text.Seq_Formats.Pad_Zero
              (Posix_Tools.Text.Seq_Formats.Trimmed_Decimal (Item, Scale), Width));
      end Default_Image;

      function Format_Image (Item : Long_Long_Integer) return String is
         Format : constant String := To_String (Format_Text);
         Parsed : constant Posix_Tools.Text.Seq_Formats.Parsed_Seq_Format :=
           Posix_Tools.Text.Seq_Formats.Parse_Seq_Format (Format);
      begin
         if not Parsed.Valid then
            return Default_Image (Item);
         end if;

         declare
            Prefix : constant String := Format (Format'First .. Parsed.Percent_Index - 1);
            Suffix : constant String :=
              (if Parsed.Conversion_Index < Format'Last
               then Format (Parsed.Conversion_Index + 1 .. Format'Last)
               else "");
            Precision : constant Natural :=
              (if Parsed.Has_Precision then Parsed.Precision else Scale);
            Number : constant String :=
              (if not Parsed.Has_Precision and then Parsed.Conversion in 'g' | 'G'
               then Default_Image (Item, Parsed.Width)
               else
                 Localize_Decimal_Number
                   (Posix_Tools.Text.Seq_Formats.Pad_Zero
                      (Posix_Tools.Text.Seq_Formats.Fixed_Decimal
                         (Item, Scale, Precision),
                       Parsed.Width)));
         begin
            return Prefix & Number & Suffix;
         end;
      end Format_Image;

      procedure Invalid (Text : String) is
      begin
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand '" & Text & "'");
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
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "missing option argument '" & Arg & "'");
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
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option " & Arg);
                  return;
               else
                  Operands.Append (Arg);
                  I := I + 1;
               end if;
            end;
         end loop;
      end;

      if Operands.Length not in 1 .. 3 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand count");
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
         Current : Long_Long_Integer := First;
         First_Output : Boolean := True;
         Width : Natural := 0;
      begin
         if Equal_Width and then not Has_Format then
            Width := Natural'Max (Default_Image (First)'Length, Default_Image (Last)'Length);
         end if;

         while (Increment > 0 and then Current <= Last) or else (Increment < 0 and then Current >= Last) loop
            if not First_Output then
               Context.Put (To_String (Separator));
               exit when Context.Output_Failed;
            end if;
            Context.Put ((if Has_Format then Format_Image (Current) else Default_Image (Current, Width)));
            exit when Context.Output_Failed;
            if Posix_Tools.Text.Decimal_Parsing.Long_Long_Addition_Overflows
              (Current, Increment)
            then
               exit;
            end if;
            Current := Current + Increment;
            First_Output := False;
         end loop;
         if not Context.Output_Failed then
            Context.Put ("" & LF);
         end if;
      end;

      Set_Success (Context, Result);
   end Run;
end Posix_Tools.Commands.Seq;
