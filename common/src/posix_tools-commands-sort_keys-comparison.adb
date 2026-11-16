with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Text.Sort_Modifiers;
with Posix_Tools.Text.Sort_Numeric;

package body Posix_Tools.Commands.Sort_Keys.Comparison is
   use Ada.Strings.Unbounded;

   LF : constant Character := Character'Val (10);

   function Compare_Bytes (Left, Right : String) return Integer is
   begin
      if Left < Right then
         return -1;
      elsif Left > Right then
         return 1;
      else
         return 0;
      end if;
   end Compare_Bytes;

   function Compare_Key_Texts
     (Left, Right : String;
      Rules       : Ordering_Rules) return Integer
   is
      Compared : constant Integer := Compare_Bytes (Left, Right);
   begin
      return (if Rules.Reverse_Order then -Compared else Compared);
   end Compare_Key_Texts;

   function Effective_Rules
     (Key    : Sort_Key_Definition;
      Global : Ordering_Rules) return Ordering_Rules is
   begin
      return (if Key.Has_Modifiers then Key.Rules else Global);
   end Effective_Rules;

   function Key_Text
     (Line       : String;
      Key        : Sort_Key_Definition;
      Rules      : Ordering_Rules;
      Options    : Sort_Options;
      Whole_Line : Boolean) return String
   is
      Locale : constant String := To_String (Options.Locale);
   begin
      if Rules.Numeric_Sort then
         declare
            Selected : constant Posix_Tools.Commands.Sort_Key_Text.Key_Range :=
              Key_Range (Line, Key, Rules, Options, Whole_Line);
         begin
            return Posix_Tools.Text.Sort_Numeric.Decimal_Sort_Key
              (Posix_Tools.Text.Sort_Numeric.Numeric_Field
                 (To_String (Options.Numeric_Locale), Line,
                  Positive (Selected.First), Selected.Last,
                  ASCII_Format => Options.ASCII_Numeric_Format));
         end;
      end if;

      --  Records hold no LF, so a LF separator makes field 1 the whole line,
      --  leading blanks included.
      return Posix_Tools.Commands.Sort_Key_Text.Sort_Key
        (Text                   => Line,
         Fold_Case              => Rules.Fold_Case,
         Ignore_Leading_Blanks  => Rules.Ignore_Leading_Blanks,
         Dictionary_Order       => Rules.Dictionary_Order,
         Ignore_Nonprinting     => Rules.Ignore_Nonprinting,
         Field_Start            => (if Whole_Line then 1 else Key.Field_Start),
         Field_End              => (if Whole_Line then 0 else Key.Field_End),
         Character_Start        => (if Whole_Line then 1 else Key.Character_Start),
         Character_End          => (if Whole_Line then 0 else Key.Character_End),
         Field_Separator        => (if Whole_Line then LF else Options.Field_Separator),
         Has_Field_Separator    => Whole_Line or else Options.Has_Field_Separator,
         Locale                 => Locale,
         Apply_Locale_Collation =>
           Posix_Tools.Text.Sort_Modifiers.Applies_Locale_Collation
             (Rules.Fold_Case, Rules.Dictionary_Order,
              Rules.Ignore_Nonprinting));
   end Key_Text;

   function Uses_Key_Range
     (Rules   : Ordering_Rules;
      Options : Sort_Options) return Boolean
   is
   begin
      return not Rules.Numeric_Sort
        and then not Rules.Fold_Case
        and then not Rules.Dictionary_Order
        and then not Rules.Ignore_Nonprinting
        and then Posix_Tools.Commands.Text_Helpers.Collation.Is_Byte_Collation_Locale
          (To_String (Options.Locale));
   end Uses_Key_Range;

   function Key_Range
     (Line       : String;
      Key        : Sort_Key_Definition;
      Rules      : Ordering_Rules;
      Options    : Sort_Options;
      Whole_Line : Boolean)
      return Posix_Tools.Commands.Sort_Key_Text.Key_Range
   is
   begin
      return Posix_Tools.Commands.Sort_Key_Text.Range_Of
        (Text                  => Line,
         Ignore_Leading_Blanks => Rules.Ignore_Leading_Blanks,
         Field_Start           => (if Whole_Line then 1 else Key.Field_Start),
         Field_End             => (if Whole_Line then 0 else Key.Field_End),
         Character_Start       => (if Whole_Line then 1 else Key.Character_Start),
         Character_End         => (if Whole_Line then 0 else Key.Character_End),
         Field_Separator       => (if Whole_Line then LF else Options.Field_Separator),
         Has_Field_Separator   => Whole_Line or else Options.Has_Field_Separator);
   end Key_Range;
end Posix_Tools.Commands.Sort_Keys.Comparison;
