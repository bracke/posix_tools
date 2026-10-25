with Posix_Tools.Commands.Sort_Key_Text;
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
      Compared : constant Integer :=
        (if Rules.Numeric_Sort
         then Posix_Tools.Text.Sort_Numeric.Decimal_Compare (Left, Right)
         else Compare_Bytes (Left, Right));
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
      --  Records hold no LF, so a LF separator makes field 1 the whole line,
      --  leading blanks included.
      Selected : constant String :=
        Posix_Tools.Commands.Sort_Key_Text.Sort_Key
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
             not Rules.Numeric_Sort
             and then Posix_Tools.Text.Sort_Modifiers.Applies_Locale_Collation
               (Rules.Fold_Case, Rules.Dictionary_Order, Rules.Ignore_Nonprinting));
   begin
      if Rules.Numeric_Sort then
         return Posix_Tools.Text.Sort_Numeric.Numeric_Field (Locale, Selected);
      else
         return Selected;
      end if;
   end Key_Text;
end Posix_Tools.Commands.Sort_Keys.Comparison;
