with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Octal_Parsing;
with Posix_Tools.Text.Printf_Arguments;
with Posix_Tools.Text.Printf_Escapes;
with Posix_Tools.Text.Printf_Formats;

package body Posix_Tools.Commands.Printf_Execution is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Text.Printf_Arguments.Conversion_Status;

   package Arguments renames Posix_Tools.Text.Printf_Arguments;
   package Formats renames Posix_Tools.Text.Printf_Formats;

   subtype Context_Class is Posix_Tools.Commands.Contexts.Context'Class;

   --  What a '%' in the format starts: "%%", a conversion specification, a
   --  '%' that starts none and is written as itself, or a specification
   --  whose field width or precision is past what can be written.
   type Spec_Kind is (Percent_Sign, Conversion, Not_A_Conversion, Bad_Format);

   --  One conversion specification: flags, field width, precision and the
   --  conversion character (XBD File Format Notation). A width or
   --  precision of '*' is taken from the next argument when it is written.
   type Conversion_Spec is record
      Kind                    : Spec_Kind := Not_A_Conversion;
      Left_Justify            : Boolean := False;
      Always_Sign             : Boolean := False;
      Blank_Sign              : Boolean := False;
      Zero_Pad                : Boolean := False;
      Alternate               : Boolean := False;
      Width                   : Natural := 0;
      Width_From_Argument     : Boolean := False;
      Has_Precision           : Boolean := False;
      Precision               : Natural := 0;
      Precision_From_Argument : Boolean := False;
      Conversion              : Character := 's';
      --  The format index after the specification.
      Next                    : Positive := 1;
   end record;

   --  What one execution carries from conversion to conversion.
   type Run_State is record
      Next_Argument  : Positive := 1;
      --  The pass over the format consumed an argument.
      Used           : Boolean := False;
      --  A \c in a %b argument ended all output.
      Stop_Output    : Boolean := False;
      Format_Ok      : Boolean := True;
      Arguments_Ok   : Boolean := True;
      --  The character locale is UTF-8, so %c and quoted characters take a
      --  whole UTF-8 character.
      UTF_8          : Boolean := False;
      Numeric_Locale : Unbounded_String;
   end record;

   Float_Conversions   : constant String := "feEgG";
   Integer_Conversions : constant String := "diuoxX";

   function Character_Locale (Context : Context_Class) return String;
   procedure Emit_Conversion
     (Context : in out Context_Class;
      State   : in out Run_State;
      Spec    : Conversion_Spec);
   --  The next argument, or "" when they ran out; either way one is used.
   function Fetch_Argument (Context : Context_Class; State : in out Run_State) return String;
   function Float_Field
     (Context : in out Context_Class;
      State   : in out Run_State;
      Spec    : Conversion_Spec) return String;
   function Integer_Field
     (Context : in out Context_Class;
      State   : in out Run_State;
      Spec    : Conversion_Spec) return String;
   function Is_One_Of (C : Character; Set : String) return Boolean is
     (for some Item of Set => Item = C);
   function Numeric_Locale (Context : Context_Class) return String;
   --  The specification at Format (Start), a '%'; no argument is read.
   function Parse_Conversion (Format : String; Start : Positive) return Conversion_Spec
     with Pre => Start in Format'Range and then Format (Start) = '%';
   procedure Report_Conversion
     (Context : in out Context_Class;
      State   : in out Run_State;
      Status  : Arguments.Conversion_Status;
      Text    : String);
   --  The next argument as the integer a '*' width or precision is.
   function Star_Value (Context : in out Context_Class; State : in out Run_State) return Long_Long_Integer;
   procedure Write_Escape
     (Context : in out Context_Class;
      Format  : String;
      Index   : in out Positive)
     with Pre => Index in Format'Range and then Format (Index) = '\';
   procedure Write_Format
     (Context : in out Context_Class;
      Format  : String;
      State   : in out Run_State);

   function Character_Locale (Context : Context_Class) return String is
      LC_All   : constant String := Context.Environment_Value ("LC_ALL");
      LC_Ctype : constant String := Context.Environment_Value ("LC_CTYPE");
      Lang     : constant String := Context.Environment_Value ("LANG");
   begin
      if LC_All /= "" then
         return LC_All;
      elsif LC_Ctype /= "" then
         return LC_Ctype;
      elsif Lang /= "" then
         return Lang;
      else
         return Context.Effective_Locale;
      end if;
   end Character_Locale;

   procedure Emit_Conversion
     (Context : in out Context_Class;
      State   : in out Run_State;
      Spec    : Conversion_Spec)
   is
      Field : Conversion_Spec := Spec;
   begin
      if Spec.Width_From_Argument then
         declare
            Value : constant Long_Long_Integer := Star_Value (Context, State);
         begin
            if abs Value > Long_Long_Integer (Natural'Last) then
               State.Format_Ok := False;
               return;
            end if;
            Field.Left_Justify := Field.Left_Justify or else Value < 0;
            Field.Width := Natural (abs Value);
         end;
      end if;

      if Spec.Precision_From_Argument then
         declare
            Value : constant Long_Long_Integer := Star_Value (Context, State);
         begin
            if Value > Long_Long_Integer (Natural'Last) then
               State.Format_Ok := False;
               return;
            end if;
            --  A negative precision is taken as if it were omitted.
            Field.Has_Precision := Value >= 0;
            Field.Precision := (if Value >= 0 then Natural (Value) else 0);
         end;
      end if;

      case Field.Conversion is
         when 's' =>
            Context.Put
              (Formats.Field_Image
                 (Fetch_Argument (Context, State),
                  Field.Width,
                  Field.Left_Justify,
                  Field.Has_Precision,
                  Field.Precision));
         when 'b' =>
            declare
               Raw : constant String := Fetch_Argument (Context, State);
            begin
               Context.Put
                 (Formats.Field_Image
                    (Posix_Tools.Text.Printf_Escapes.Decode_Backslash_Text (Raw),
                     Field.Width,
                     Field.Left_Justify,
                     Field.Has_Precision,
                     Field.Precision));
               State.Stop_Output := Posix_Tools.Text.Printf_Escapes.Stop_Decoding (Raw);
            end;
         when 'c' =>
            Context.Put
              (Formats.Field_Image
                 (Arguments.First_Character (Fetch_Argument (Context, State), State.UTF_8),
                  Field.Width,
                  Field.Left_Justify));
         when others =>
            if Is_One_Of (Field.Conversion, Integer_Conversions) then
               Context.Put (Integer_Field (Context, State, Field));
            else
               Context.Put (Float_Field (Context, State, Field));
            end if;
      end case;
   end Emit_Conversion;

   procedure Execute
     (Context        : in out Posix_Tools.Commands.Contexts.Context'Class;
      Format         : String;
      First_Argument : Positive;
      Format_Ok      : out Boolean;
      Arguments_Ok   : out Boolean)
   is
      State : Run_State;
   begin
      State.Next_Argument := First_Argument;
      State.UTF_8 := Arguments.Is_UTF_8_Locale (Character_Locale (Context));
      State.Numeric_Locale := To_Unbounded_String (Numeric_Locale (Context));

      loop
         Write_Format (Context, Format, State);
         exit when not State.Used
           or else State.Stop_Output
           or else not State.Format_Ok
           or else State.Next_Argument > Context.Argument_Count;
      end loop;

      Format_Ok := State.Format_Ok;
      Arguments_Ok := State.Arguments_Ok;
   end Execute;

   function Fetch_Argument (Context : Context_Class; State : in out Run_State) return String is
      Index : constant Positive := State.Next_Argument;
   begin
      State.Next_Argument := State.Next_Argument + 1;
      State.Used := True;
      return (if Index <= Context.Argument_Count then Context.Argument (Index) else "");
   end Fetch_Argument;

   function Float_Field
     (Context : in out Context_Class;
      State   : in out Run_State;
      Spec    : Conversion_Spec) return String
   is
      Text      : constant String := Fetch_Argument (Context, State);
      Value     : constant Arguments.Float_Argument := Arguments.Float_Value (Text, State.UTF_8);
      Digits_After : constant Natural := (if Spec.Has_Precision then Spec.Precision else 6);
      Image_Ok  : Boolean;

      function Image_Of (Number : String) return String is
        (case Spec.Conversion is
           when 'f' =>
              Formats.Fixed_Float_Image
                (Number, Digits_After, Spec.Always_Sign, Spec.Blank_Sign, Image_Ok),
           when 'e' | 'E' =>
              Formats.Scientific_Float_Image
                (Number, Digits_After, Spec.Conversion = 'E', Spec.Always_Sign, Spec.Blank_Sign,
                 Spec.Alternate, Image_Ok),
           when others =>
              Formats.General_Float_Image
                (Number, Digits_After, Spec.Conversion = 'G', Spec.Always_Sign, Spec.Blank_Sign,
                 Spec.Alternate, Image_Ok));

      Image : constant String := Image_Of (To_String (Value.Image));
   begin
      Report_Conversion (Context, State, Value.Status, Text);
      if not Image_Ok then
         --  A value the float images cannot write is diagnosed already or
         --  past their range; it is written as zero.
         if Value.Status = Arguments.Converted then
            Report_Conversion (Context, State, Arguments.Out_Of_Range, Text);
         end if;
         declare
            Zero : constant String := Image_Of ("0");
         begin
            return Formats.Field_Image
              (Formats.Localize_Decimal_Number (Zero, To_String (State.Numeric_Locale), True),
               Spec.Width, Spec.Left_Justify, Pad => (if Spec.Zero_Pad then '0' else ' '));
         end;
      end if;

      return Formats.Field_Image
        (Formats.Localize_Decimal_Number (Image, To_String (State.Numeric_Locale), True),
         Spec.Width,
         Spec.Left_Justify,
         Pad => (if Spec.Zero_Pad then '0' else ' '));
   end Float_Field;

   function Integer_Field
     (Context : in out Context_Class;
      State   : in out Run_State;
      Spec    : Conversion_Spec) return String
   is
      Text   : constant String := Fetch_Argument (Context, State);
      Value  : Arguments.Integer_Argument := Arguments.Integer_Value (Text, State.UTF_8);
      Signed : constant Boolean := Spec.Conversion in 'd' | 'i';
      Image  : constant String :=
        (if Signed then Arguments.Signed_Image (Value)
         else Arguments.Unsigned_Image
           (Value,
            (case Spec.Conversion is
               when 'o' => 8,
               when 'x' | 'X' => 16,
               when others => 10),
            Spec.Conversion = 'X'));
      Formatted : constant String :=
        Formats.Decimal_With_Precision
          (Image,
           Spec.Has_Precision,
           Spec.Precision,
           Spec.Always_Sign and then Signed,
           Spec.Blank_Sign and then Signed);
      Zero_Value : constant Boolean := Formatted = "" or else Formatted = "0";
      Prefixed   : constant String :=
        (if Spec.Alternate and then not Zero_Value then
           (case Spec.Conversion is
              when 'o' => (if Formatted (Formatted'First) = '0' then Formatted else "0" & Formatted),
              when 'x' => "0x" & Formatted,
              when 'X' => "0X" & Formatted,
              when others => Formatted)
         else Formatted);
   begin
      Report_Conversion (Context, State, Value.Status, Text);
      return Formats.Field_Image
        ((if Spec.Conversion in 'd' | 'i' | 'u'
          then Formats.Localize_Decimal_Number (Prefixed, To_String (State.Numeric_Locale), False)
          else Prefixed),
         Spec.Width,
         Spec.Left_Justify,
         Pad => (if Spec.Zero_Pad and then not Spec.Has_Precision then '0' else ' '));
   end Integer_Field;

   function Numeric_Locale (Context : Context_Class) return String is
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

   function Parse_Conversion (Format : String; Start : Positive) return Conversion_Spec is
      Spec : Conversion_Spec;
      J    : Positive := Start + 1;

      function Field_At (Value : out Natural) return Boolean;

      --  Decimal digits at J into Value, J moved past them; False when they
      --  are past Natural, or end the format.
      function Field_At (Value : out Natural) return Boolean is
         Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural_Field :=
           Posix_Tools.Text.Decimal_Parsing.Natural_Field (Format, J);
      begin
         Value := Parsed.Value;
         if not Parsed.Valid then
            Spec.Kind := Bad_Format;
            return False;
         elsif Parsed.At_End then
            Spec.Kind := Not_A_Conversion;
            return False;
         end if;
         J := Parsed.Next;
         return True;
      end Field_At;
   begin
      Spec.Next := Start + 1;
      if J > Format'Last then
         return Spec;
      elsif Format (J) = '%' then
         Spec.Kind := Percent_Sign;
         Spec.Next := J + 1;
         return Spec;
      end if;

      while J <= Format'Last and then Format (J) in '-' | '+' | ' ' | '0' | '#' loop
         case Format (J) is
            when '-' => Spec.Left_Justify := True;
            when '+' => Spec.Always_Sign := True;
            when ' ' => Spec.Blank_Sign := True;
            when '0' => Spec.Zero_Pad := True;
            when others => Spec.Alternate := True;
         end case;
         J := J + 1;
      end loop;
      --  '+' overrides ' ' (XBD File Format Notation).
      Spec.Blank_Sign := Spec.Blank_Sign and then not Spec.Always_Sign;

      if J <= Format'Last and then Format (J) = '*' then
         Spec.Width_From_Argument := True;
         J := J + 1;
      elsif J <= Format'Last
        and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Format (J))
        and then not Field_At (Spec.Width)
      then
         return Spec;
      end if;

      if J <= Format'Last and then Format (J) = '.' then
         Spec.Has_Precision := True;
         J := J + 1;
         if J <= Format'Last and then Format (J) = '*' then
            Spec.Precision_From_Argument := True;
            J := J + 1;
         elsif J <= Format'Last
           and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Format (J))
           and then not Field_At (Spec.Precision)
         then
            return Spec;
         end if;
      end if;

      if J <= Format'Last
        and then (Is_One_Of (Format (J), "sbc") or else Is_One_Of (Format (J), Integer_Conversions)
                  or else Is_One_Of (Format (J), Float_Conversions))
      then
         Spec.Kind := Conversion;
         Spec.Conversion := Format (J);
         Spec.Next := J + 1;
      end if;
      return Spec;
   end Parse_Conversion;

   procedure Report_Conversion
     (Context : in out Context_Class;
      State   : in out Run_State;
      Status  : Arguments.Conversion_Status;
      Text    : String)
   is
   begin
      case Status is
         when Arguments.Converted =>
            return;
         when Arguments.Not_Numeric =>
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Text, "posix_tools.diagnostic.number.expected", "expected a numeric value");
         when Arguments.Partially_Converted =>
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Text, "posix_tools.diagnostic.number.not_completely_converted",
               "value not completely converted");
         when Arguments.Out_Of_Range =>
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Text, "posix_tools.diagnostic.number.out_of_range", "numeric result out of range");
      end case;
      State.Arguments_Ok := False;
   end Report_Conversion;

   function Star_Value (Context : in out Context_Class; State : in out Run_State) return Long_Long_Integer is
      Text  : constant String := Fetch_Argument (Context, State);
      Value : Arguments.Integer_Argument := Arguments.Integer_Value (Text, State.UTF_8);
      Image : constant String := Arguments.Signed_Image (Value);
   begin
      Report_Conversion (Context, State, Value.Status, Text);
      return Long_Long_Integer'Value (Image);
   end Star_Value;

   --  A backslash escape of the format (XBD File Format Notation): the
   --  named ones, and \ddd, one to three octal digits, as that byte.
   procedure Write_Escape
     (Context : in out Context_Class;
      Format  : String;
      Index   : in out Positive)
   is
      Named : Character;
   begin
      if Index = Format'Last then
         Context.Put ("\");
         Index := Index + 1;
         return;
      end if;

      case Format (Index + 1) is
         when 'a' => Named := Character'Val (7);
         when 'b' => Named := Character'Val (8);
         when 'f' => Named := Character'Val (12);
         when 'n' => Named := Character'Val (10);
         when 'r' => Named := Character'Val (13);
         when 't' => Named := Character'Val (9);
         when 'v' => Named := Character'Val (11);
         when '\' => Named := '\';
         when '0' .. '7' =>
            declare
               Parsed : constant Posix_Tools.Text.Octal_Parsing.Parsed_Octal_Prefix :=
                 Posix_Tools.Text.Octal_Parsing.Prefix_Value (Format (Index + 1 .. Format'Last), 3);
            begin
               Context.Put ("" & Character'Val (Parsed.Value mod 256));
               Index := Index + 1 + Parsed.Count;
               return;
            end;
         when others =>
            --  Not an escape: the backslash is written as itself.
            Context.Put ("\");
            Index := Index + 1;
            return;
      end case;

      Context.Put ("" & Named);
      Index := Index + 2;
   end Write_Escape;

   procedure Write_Format
     (Context : in out Context_Class;
      Format  : String;
      State   : in out Run_State)
   is
      I : Positive := Format'First;
   begin
      State.Used := False;
      while I <= Format'Last and then not State.Stop_Output loop
         if Format (I) = '%' then
            declare
               Spec : constant Conversion_Spec := Parse_Conversion (Format, I);
            begin
               case Spec.Kind is
                  when Percent_Sign | Not_A_Conversion =>
                     Context.Put ("%");
                  when Conversion =>
                     Emit_Conversion (Context, State, Spec);
                     exit when not State.Format_Ok;
                  when Bad_Format =>
                     State.Format_Ok := False;
                     exit;
               end case;
               I := Spec.Next;
            end;
         elsif Format (I) = '\' then
            Write_Escape (Context, Format, I);
         else
            Context.Put ("" & Format (I));
            I := I + 1;
         end if;
      end loop;
   end Write_Format;
end Posix_Tools.Commands.Printf_Execution;
