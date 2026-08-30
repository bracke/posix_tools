private package Posix_Tools.Commands.Sort_Keys.Comparison is
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
      return Boolean;

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
      Locale : String := "") return Integer;
end Posix_Tools.Commands.Sort_Keys.Comparison;
