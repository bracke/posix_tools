with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Octal_Parsing;
with Posix_Tools.Text.Printf_Escapes;
with Posix_Tools.Text.Printf_Formats;

package body Posix_Tools.Commands.Printf_Execution is
   package Formats renames Posix_Tools.Text.Printf_Formats;

   LF : constant Character := Character'Val (10);

   procedure Execute
     (Context        : in out Posix_Tools.Commands.Contexts.Context'Class;
      Format         : String;
      First_Argument : Positive;
      Ok             : out Boolean)
   is
      Arg           : Positive := First_Argument;
      Used_Argument : Boolean := False;
      Stop_Output   : Boolean := False;

      function Numeric_Locale return String;
      function Localized_Number
        (Text           : String;
         Localize_Radix : Boolean) return String;
      function Numeric_Image
        (Specifier    : Character;
         Numeric_Text : String;
         Precision    : Natural;
         Has_Precision : Boolean;
         Always_Sign  : Boolean;
         Blank_Sign   : Boolean;
         Alternate    : Boolean;
         Image_Ok     : out Boolean) return String;
      procedure Put_Field
        (Text          : String;
         Width         : Natural;
         Left_Justify  : Boolean := False;
         Has_Precision : Boolean := False;
         Precision     : Natural := 0;
         Pad           : Character := ' ');
      procedure Write_Format (Used : out Boolean);

      function Localized_Number
        (Text           : String;
         Localize_Radix : Boolean) return String
      is
      begin
         return Formats.Localize_Decimal_Number
           (Text, Numeric_Locale, Localize_Radix);
      end Localized_Number;

      function Numeric_Image
        (Specifier    : Character;
         Numeric_Text : String;
         Precision    : Natural;
         Has_Precision : Boolean;
         Always_Sign  : Boolean;
         Blank_Sign   : Boolean;
         Alternate    : Boolean;
         Image_Ok     : out Boolean) return String
      is
      begin
         if Specifier in 'd' | 'i' then
            return Formats.Canonical_Decimal (Numeric_Text, Image_Ok);
         elsif Specifier = 'u' then
            return Formats.Canonical_Unsigned (Numeric_Text, Image_Ok);
         elsif Specifier = 'o' then
            return Formats.Unsigned_Image (Numeric_Text, 8, False, Image_Ok);
         elsif Specifier = 'f' then
            return Formats.Fixed_Float_Image
              (Numeric_Text,
               (if Has_Precision then Precision else 6),
               Always_Sign,
               Blank_Sign,
               Image_Ok);
         elsif Specifier in 'e' | 'E' then
            return Formats.Scientific_Float_Image
              (Numeric_Text,
               (if Has_Precision then Precision else 6),
               Specifier = 'E',
               Always_Sign,
               Blank_Sign,
               Alternate,
               Image_Ok);
         elsif Specifier in 'g' | 'G' then
            return Formats.General_Float_Image
              (Numeric_Text,
               (if Has_Precision then Precision else 6),
               Specifier = 'G',
               Always_Sign,
               Blank_Sign,
               Alternate,
               Image_Ok);
         else
            return Formats.Unsigned_Image (Numeric_Text, 16, Specifier = 'X', Image_Ok);
         end if;
      end Numeric_Image;

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

      procedure Put_Field
        (Text          : String;
         Width         : Natural;
         Left_Justify  : Boolean := False;
         Has_Precision : Boolean := False;
         Precision     : Natural := 0;
         Pad           : Character := ' ')
      is
      begin
         Context.Put
           (Formats.Field_Image
              (Text, Width, Left_Justify, Has_Precision, Precision, Pad));
      end Put_Field;

      procedure Write_Format (Used : out Boolean) is
         I : Positive := Format'First;

         function Consume_Star_Value (Star_Ok : out Boolean) return Long_Long_Integer;

         function Consume_Star_Value (Star_Ok : out Boolean) return Long_Long_Integer is
         begin
            if Arg > Context.Argument_Count then
               Star_Ok := True;
               Used := True;
               return 0;
            end if;

            declare
               Value : constant Long_Long_Integer :=
                 Formats.Parse_Checked_Signed (Context.Argument (Arg), Star_Ok);
            begin
               Arg := Arg + 1;
               Used := True;
               return Value;
            end;
         end Consume_Star_Value;
      begin
         Used := False;
         while I <= Format'Last and then not Stop_Output loop
            if Format (I) = '%' and then I < Format'Last and then Format (I + 1) = 's' then
               Context.Put ((if Arg <= Context.Argument_Count then Context.Argument (Arg) else ""));
               Arg := Arg + 1;
               Used := True;
               I := I + 2;
            elsif Format (I) = '%' and then I < Format'Last and then Format (I + 1) = 'b' then
               if Arg <= Context.Argument_Count then
                  declare
                     Raw     : constant String := Context.Argument (Arg);
                     Decoded : constant String :=
                       Posix_Tools.Text.Printf_Escapes.Decode_Backslash_Text (Raw);
                  begin
                     Context.Put (Decoded);
                     Stop_Output := Posix_Tools.Text.Printf_Escapes.Stop_Decoding (Raw);
                  end;
               end if;
               Arg := Arg + 1;
               Used := True;
               I := I + 2;
            elsif Format (I) = '%'
              and then I < Format'Last
              and then Format (I + 1) in 'd' | 'i' | 'u' | 'o' | 'x' | 'X' | 'f' | 'e'
                | 'E' | 'g' | 'G'
            then
               declare
                  Specifier    : constant Character := Format (I + 1);
                  Numeric_Text : constant String :=
                    (if Arg <= Context.Argument_Count then Context.Argument (Arg) else "0");
                  Numeric_Ok   : Boolean;
                  Image        : constant String :=
                    Numeric_Image
                      (Specifier, Numeric_Text, 6, False, False, False, False, Numeric_Ok);
               begin
                  if Numeric_Ok then
                     Context.Put
                       ((if Specifier in 'd' | 'i' | 'u' | 'f' | 'e' | 'E' | 'g' | 'G'
                         then Localized_Number
                           (Image, Specifier in 'f' | 'e' | 'E' | 'g' | 'G')
                         else Image));
                  else
                     Ok := False;
                  end if;
               end;
               Arg := Arg + 1;
               Used := True;
               I := I + 2;
            elsif Format (I) = '%'
              and then I < Format'Last
              and then
                (Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Format (I + 1))
                 or else Format (I + 1) = '.'
                 or else Format (I + 1) = '*'
                 or else Format (I + 1) in '-' | '+' | ' ' | '#')
            then
               declare
                  J             : Natural := I + 1;
                  Width         : Natural := 0;
                  Left_Justify  : Boolean := False;
                  Always_Sign   : Boolean := False;
                  Blank_Sign    : Boolean := False;
                  Zero_Pad      : Boolean := False;
                  Alternate     : Boolean := False;
                  Has_Precision : Boolean := False;
                  Precision     : Natural := 0;
               begin
                  while J <= Format'Last and then Format (J) in '-' | '+' | ' ' | '0' | '#' loop
                     case Format (J) is
                        when '-' =>
                           Left_Justify := True;
                        when '+' =>
                           Always_Sign := True;
                           Blank_Sign := False;
                        when ' ' =>
                           if not Always_Sign then
                              Blank_Sign := True;
                           end if;
                        when '0' =>
                           Zero_Pad := True;
                        when '#' =>
                           Alternate := True;
                        when others =>
                           null;
                     end case;
                     J := J + 1;
                  end loop;

                  if J > Format'Last
                    or else
                      (not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Format (J))
                       and then Format (J) /= '.'
                       and then Format (J) /= '*'
                       and then Format (J) not in
                         's' | 'b' | 'c' | 'd' | 'i' | 'u' | 'o' | 'x' | 'X' | 'f'
                           | 'e' | 'E' | 'g' | 'G')
                  then
                     Context.Put ("%");
                     I := I + 1;
                  else
                     if J <= Format'Last and then Format (J) = '*' then
                        declare
                           Star_Ok    : Boolean;
                           Star_Value : constant Long_Long_Integer := Consume_Star_Value (Star_Ok);
                        begin
                           if not Star_Ok or else abs Star_Value > Long_Long_Integer (Natural'Last) then
                              Ok := False;
                              return;
                           elsif Star_Value < 0 then
                              Left_Justify := True;
                              Width := Natural (-Star_Value);
                           else
                              Width := Natural (Star_Value);
                           end if;
                           J := J + 1;
                        end;
                     end if;

                     if J <= Format'Last
                       and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Format (J))
                     then
                        declare
                           Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural_Field :=
                             Posix_Tools.Text.Decimal_Parsing.Natural_Field (Format, J);
                        begin
                           if not Parsed.Valid then
                              Ok := False;
                              return;
                           end if;
                           Width := Parsed.Value;
                           if Parsed.At_End then
                              Context.Put ("%");
                              I := I + 1;
                              return;
                           end if;
                           J := Parsed.Next;
                        end;
                     end if;

                     if J <= Format'Last and then Format (J) = '.' then
                        Has_Precision := True;
                        J := J + 1;
                        if J <= Format'Last and then Format (J) = '*' then
                           declare
                              Star_Ok    : Boolean;
                              Star_Value : constant Long_Long_Integer := Consume_Star_Value (Star_Ok);
                           begin
                              if not Star_Ok or else Star_Value > Long_Long_Integer (Natural'Last) then
                                 Ok := False;
                                 return;
                              elsif Star_Value < 0 then
                                 Has_Precision := False;
                                 Precision := 0;
                              else
                                 Precision := Natural (Star_Value);
                              end if;
                              J := J + 1;
                           end;
                        end if;

                        if J <= Format'Last
                          and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Format (J))
                        then
                           declare
                              Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural_Field :=
                                Posix_Tools.Text.Decimal_Parsing.Natural_Field (Format, J);
                           begin
                              if not Parsed.Valid then
                                 Ok := False;
                                 return;
                              end if;
                              Precision := Parsed.Value;
                              if Parsed.At_End then
                                 Context.Put ("%");
                                 I := I + 1;
                                 return;
                              end if;
                              J := Parsed.Next;
                           end;
                        end if;
                     end if;

                     if J <= Format'Last and then Format (J) = 's' then
                        Put_Field
                          ((if Arg <= Context.Argument_Count then Context.Argument (Arg) else ""),
                           Width,
                           Left_Justify,
                           Has_Precision,
                           Precision);
                        Arg := Arg + 1;
                        Used := True;
                        I := J + 1;
                     elsif J <= Format'Last and then Format (J) = 'b' then
                        if Arg <= Context.Argument_Count then
                           declare
                              Raw     : constant String := Context.Argument (Arg);
                              Decoded : constant String :=
                                Posix_Tools.Text.Printf_Escapes.Decode_Backslash_Text (Raw);
                           begin
                              Put_Field
                                (Decoded, Width, Left_Justify, Has_Precision, Precision);
                              Stop_Output :=
                                Posix_Tools.Text.Printf_Escapes.Stop_Decoding (Raw);
                           end;
                        end if;
                        Arg := Arg + 1;
                        Used := True;
                        I := J + 1;
                     elsif J <= Format'Last and then Format (J) = 'c' then
                        declare
                           Field : constant String :=
                             (if Arg <= Context.Argument_Count and then Context.Argument (Arg) /= ""
                              then "" & Context.Argument (Arg) (Context.Argument (Arg)'First)
                              else "");
                        begin
                           Put_Field (Field, Width, Left_Justify);
                        end;
                        Arg := Arg + 1;
                        Used := True;
                        I := J + 1;
                     elsif J <= Format'Last
                       and then Format (J) in 'd' | 'i' | 'u' | 'o' | 'x' | 'X' | 'f' | 'e'
                         | 'E' | 'g' | 'G'
                     then
                        declare
                           Specifier    : constant Character := Format (J);
                           Numeric_Text : constant String :=
                             (if Arg <= Context.Argument_Count then Context.Argument (Arg) else "0");
                           Numeric_Ok   : Boolean;
                           Image        : constant String :=
                             Numeric_Image
                               (Specifier,
                                Numeric_Text,
                                Precision,
                                Has_Precision,
                                Always_Sign,
                                Blank_Sign,
                                Alternate,
                                Numeric_Ok);
                        begin
                           if Numeric_Ok then
                              declare
                                 Formatted : constant String :=
                                   (if Specifier in 'f' | 'e' | 'E' | 'g' | 'G'
                                    then Image
                                    else Formats.Decimal_With_Precision
                                      (Image,
                                       Has_Precision,
                                       Precision,
                                       Always_Sign and then Specifier in 'd' | 'i',
                                       Blank_Sign and then Specifier in 'd' | 'i'));
                                 Zero_Value : constant Boolean :=
                                   Formatted = "" or else Formatted = "0";
                                 Alternate_Image : constant String :=
                                   (if Alternate and then Specifier = 'o' and then not Zero_Value
                                    then "0" & Formatted
                                    elsif Alternate and then Specifier = 'x' and then not Zero_Value
                                    then "0x" & Formatted
                                    elsif Alternate and then Specifier = 'X' and then not Zero_Value
                                    then "0X" & Formatted
                                    else Formatted);
                                 Localized_Image : constant String :=
                                   (if Specifier in 'd' | 'i' | 'u' | 'f' | 'e' | 'E' | 'g' | 'G'
                                    then Localized_Number
                                      (Alternate_Image,
                                       Specifier in 'f' | 'e' | 'E' | 'g' | 'G')
                                    else Alternate_Image);
                              begin
                                 Put_Field
                                   (Localized_Image,
                                    Width,
                                    Left_Justify,
                                    Pad =>
                                      (if Zero_Pad
                                         and then (Specifier in 'f' | 'e' | 'E' | 'g' | 'G'
                                                   or else not Has_Precision)
                                       then '0'
                                       else ' '));
                              end;
                           else
                              Ok := False;
                           end if;
                        end;
                        Arg := Arg + 1;
                        Used := True;
                        I := J + 1;
                     else
                        Context.Put ("%");
                        I := I + 1;
                     end if;
                  end if;
               end;
            elsif Format (I) = '%' and then I < Format'Last and then Format (I + 1) = 'c' then
               if Arg <= Context.Argument_Count and then Context.Argument (Arg) /= "" then
                  Context.Put ("" & Context.Argument (Arg) (Context.Argument (Arg)'First));
               end if;
               Arg := Arg + 1;
               Used := True;
               I := I + 2;
            elsif Format (I) = '%' and then I < Format'Last and then Format (I + 1) = '%' then
               Context.Put ("%");
               I := I + 2;
            elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'a' then
               Context.Put ("" & Character'Val (7));
               I := I + 2;
            elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'b' then
               Context.Put ("" & Character'Val (8));
               I := I + 2;
            elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'f' then
               Context.Put ("" & Character'Val (12));
               I := I + 2;
            elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'n' then
               Context.Put ("" & LF);
               I := I + 2;
            elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 't' then
               Context.Put ("" & Character'Val (9));
               I := I + 2;
            elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'r' then
               Context.Put ("" & Character'Val (13));
               I := I + 2;
            elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = 'v' then
               Context.Put ("" & Character'Val (11));
               I := I + 2;
            elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = '\' then
               Context.Put ("\");
               I := I + 2;
            elsif Format (I) = '\' and then I < Format'Last and then Format (I + 1) = '0' then
               declare
                  Parsed : constant Posix_Tools.Text.Octal_Parsing.Parsed_Octal_Prefix :=
                    Posix_Tools.Text.Octal_Parsing.Prefix_Value
                      (Format (I + 2 .. Format'Last), 3);
               begin
                  Context.Put ("" & Character'Val (Parsed.Value mod 256));
                  I := I + Parsed.Count + 2;
               end;
            else
               Context.Put ("" & Format (I));
               I := I + 1;
            end if;
         end loop;
      end Write_Format;
   begin
      Ok := True;
      Write_Format (Used_Argument);
      while Used_Argument and then Arg <= Context.Argument_Count loop
         Write_Format (Used_Argument);
      end loop;
   end Execute;
end Posix_Tools.Commands.Printf_Execution;
