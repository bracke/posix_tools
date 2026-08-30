package Posix_Tools.Commands.Sort_Key_Text is
   function Sort_Key
     (Text : String;
      Fold_Case, Ignore_Leading_Blanks, Dictionary_Order, Ignore_Nonprinting : Boolean;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Field_Separator : Character := ' ';
      Has_Field_Separator : Boolean := False;
      Locale : String := "";
      Apply_Locale_Collation : Boolean := True) return String;
end Posix_Tools.Commands.Sort_Key_Text;
