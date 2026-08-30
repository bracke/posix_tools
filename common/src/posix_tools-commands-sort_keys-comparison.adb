with Posix_Tools.Commands.Sort_Key_Text;
with Posix_Tools.Text.Sort_Modifiers;
with Posix_Tools.Text.Sort_Numeric;

package body Posix_Tools.Commands.Sort_Keys.Comparison is
   use Posix_Tools.Commands.Sort_Key_Text;

   function Line_Greater
     (Left, Right : String;
      Fold_Case,
      Numeric_Sort,
      Ignore_Leading_Blanks,
      Stable_Sort,
      Dictionary_Order,
      Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "")
      return Boolean
   is
      Left_Char : Character;
      Right_Char : Character;
      Left_Key : constant String :=
        Sort_Key
          (Left,
           Fold_Case,
           Ignore_Leading_Blanks,
           Dictionary_Order,
           Ignore_Nonprinting,
           Field_Start,
           Field_End,
           Character_Start,
           Character_End,
           Field_Separator,
           Has_Field_Separator,
           Locale,
           Posix_Tools.Text.Sort_Modifiers.Applies_Locale_Collation
             (Fold_Case, Dictionary_Order, Ignore_Nonprinting));
      Right_Key : constant String :=
        Sort_Key
          (Right,
           Fold_Case,
           Ignore_Leading_Blanks,
           Dictionary_Order,
           Ignore_Nonprinting,
           Field_Start,
           Field_End,
           Character_Start,
           Character_End,
           Field_Separator,
           Has_Field_Separator,
           Locale,
           Posix_Tools.Text.Sort_Modifiers.Applies_Locale_Collation
             (Fold_Case, Dictionary_Order, Ignore_Nonprinting));
      Left_Index : Natural := Left_Key'First;
      Right_Index : Natural := Right_Key'First;
   begin
      if Numeric_Sort then
         declare
            Left_Numeric_Key : constant String :=
              Sort_Key
                (Left,
                 Fold_Case,
                 Ignore_Leading_Blanks,
                 Dictionary_Order,
                 Ignore_Nonprinting,
                 Field_Start,
                 Field_End,
                 Character_Start,
                 Character_End,
                 Field_Separator,
                 Has_Field_Separator,
                 Locale,
                 False);
            Right_Numeric_Key : constant String :=
              Sort_Key
                (Right,
                 Fold_Case,
                 Ignore_Leading_Blanks,
                 Dictionary_Order,
                 Ignore_Nonprinting,
                 Field_Start,
                 Field_End,
                 Character_Start,
                 Character_End,
                 Field_Separator,
                 Has_Field_Separator,
                 Locale,
                 False);
            Numeric_Result : constant Integer :=
              Posix_Tools.Text.Sort_Numeric.Numeric_Compare
                (Locale, Left_Numeric_Key, Right_Numeric_Key);
         begin
            if Numeric_Result /= 0 then
               return Numeric_Result > 0;
            elsif Stable_Sort then
               return False;
            end if;
         end;
      end if;

      if not Fold_Case then
         return Left_Key > Right_Key;
      end if;

      while Left_Index <= Left_Key'Last and then Right_Index <= Right_Key'Last loop
         Left_Char := Left_Key (Left_Index);
         Right_Char := Right_Key (Right_Index);
         if Left_Char > Right_Char then
            return True;
         elsif Left_Char < Right_Char then
            return False;
         end if;
         Left_Index := Left_Index + 1;
         Right_Index := Right_Index + 1;
      end loop;

      return Left_Key'Length > Right_Key'Length;
   end Line_Greater;

   function Sort_Key_Comparison
     (Left, Right : String;
      Key : Sort_Key_Definition;
      Fold_Case,
      Numeric_Sort,
      Ignore_Leading_Blanks,
      Dictionary_Order,
      Ignore_Nonprinting : Boolean;
      Field_Separator : Character;
      Has_Field_Separator : Boolean;
      Locale : String := "") return Integer
   is
      Effective_Fold_Case : constant Boolean := Fold_Case or else Key.Fold_Case;
      Effective_Numeric_Sort : constant Boolean := Numeric_Sort or else Key.Numeric_Sort;
      Effective_Dictionary_Order : constant Boolean := Dictionary_Order or else Key.Dictionary_Order;
      Effective_Ignore_Nonprinting : constant Boolean := Ignore_Nonprinting or else Key.Ignore_Nonprinting;
      Left_Key : constant String :=
        Sort_Key
          (Left,
           Effective_Fold_Case,
           Ignore_Leading_Blanks or else Key.Ignore_Leading_Blanks,
           Effective_Dictionary_Order,
           Effective_Ignore_Nonprinting,
           Key.Field_Start,
           Key.Field_End,
           Key.Character_Start,
           Key.Character_End,
           Field_Separator,
           Has_Field_Separator,
           Locale,
           Posix_Tools.Text.Sort_Modifiers.Applies_Locale_Collation
             (Effective_Fold_Case, Effective_Dictionary_Order, Effective_Ignore_Nonprinting));
      Right_Key : constant String :=
        Sort_Key
          (Right,
           Effective_Fold_Case,
           Ignore_Leading_Blanks or else Key.Ignore_Leading_Blanks,
           Effective_Dictionary_Order,
           Effective_Ignore_Nonprinting,
           Key.Field_Start,
           Key.Field_End,
           Key.Character_Start,
           Key.Character_End,
           Field_Separator,
           Has_Field_Separator,
           Locale,
           Posix_Tools.Text.Sort_Modifiers.Applies_Locale_Collation
             (Effective_Fold_Case, Effective_Dictionary_Order, Effective_Ignore_Nonprinting));
      Numeric_Result : Integer;
   begin
      if Effective_Numeric_Sort then
         declare
            Left_Numeric_Key : constant String :=
              Sort_Key
                (Left,
                 Effective_Fold_Case,
                 Ignore_Leading_Blanks or else Key.Ignore_Leading_Blanks,
                 Effective_Dictionary_Order,
                 Effective_Ignore_Nonprinting,
                 Key.Field_Start,
                 Key.Field_End,
                 Key.Character_Start,
                 Key.Character_End,
                 Field_Separator,
                 Has_Field_Separator,
                 Locale,
                 False);
            Right_Numeric_Key : constant String :=
              Sort_Key
                (Right,
                 Effective_Fold_Case,
                 Ignore_Leading_Blanks or else Key.Ignore_Leading_Blanks,
                 Effective_Dictionary_Order,
                 Effective_Ignore_Nonprinting,
                 Key.Field_Start,
                 Key.Field_End,
                 Key.Character_Start,
                 Key.Character_End,
                 Field_Separator,
                 Has_Field_Separator,
                 Locale,
                 False);
         begin
            Numeric_Result :=
              Posix_Tools.Text.Sort_Numeric.Numeric_Compare
                (Locale, Left_Numeric_Key, Right_Numeric_Key);
         end;
         if Numeric_Result /= 0 then
            return Numeric_Result;
         end if;
      end if;

      if Left_Key > Right_Key then
         return 1;
      elsif Left_Key < Right_Key then
         return -1;
      else
         return 0;
      end if;
   end Sort_Key_Comparison;
end Posix_Tools.Commands.Sort_Keys.Comparison;
