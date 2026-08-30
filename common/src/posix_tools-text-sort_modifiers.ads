package Posix_Tools.Text.Sort_Modifiers
  with SPARK_Mode => On
is
   type Parsed_Key_Number is record
      Valid      : Boolean := False;
      Value      : Natural := 0;
      Last_Digit : Natural := 0;
   end record;

   type Parsed_Key is record
      Valid : Boolean := False;
      Field_Start : Positive := 1;
      Field_End : Natural := 0;
      Character_Start : Positive := 1;
      Character_End : Natural := 0;
      Fold_Case : Boolean := False;
      Numeric_Sort : Boolean := False;
      Ignore_Leading_Blanks : Boolean := False;
      Dictionary_Order : Boolean := False;
      Ignore_Nonprinting : Boolean := False;
      Reverse_Order : Boolean := False;
   end record;

   function Applies_Locale_Collation
     (Fold_Case, Dictionary_Order, Ignore_Nonprinting : Boolean) return Boolean
     with Post =>
       Applies_Locale_Collation'Result =
         not (Fold_Case or else Dictionary_Order or else Ignore_Nonprinting);

   function Is_Key_Modifier (Ch : Character) return Boolean
     with Post =>
       Is_Key_Modifier'Result =
         (Ch = 'b' or else Ch = 'd' or else Ch = 'f'
          or else Ch = 'i' or else Ch = 'n' or else Ch = 'r');

   function Parse_Positive_Key_Number
     (Text  : String;
      Start : Positive;
      Stop  : Natural) return Parsed_Key_Number
     with
       Pre =>
         Text'First in Positive
         and then Text'Last < Positive'Last
         and then Start >= Text'First
         and then Start <= Text'Last + 1
         and then Stop <= Text'Last,
       Post =>
         (if Parse_Positive_Key_Number'Result.Valid then
            Parse_Positive_Key_Number'Result.Value > 0
            and then Parse_Positive_Key_Number'Result.Last_Digit in Start .. Stop
         else
            Parse_Positive_Key_Number'Result.Value = 0);

   function Parse_Key (Text : String) return Parsed_Key
     with
       Pre => Text'First in Positive and then Text'Last < Positive'Last,
       Post =>
         (if Parse_Key'Result.Valid then
            Parse_Key'Result.Field_Start > 0
            and then Parse_Key'Result.Character_Start > 0
            and then
              (Parse_Key'Result.Field_End = 0
               or else Parse_Key'Result.Field_End >= Parse_Key'Result.Field_Start)
          else
            Parse_Key'Result.Field_Start = 1
            and then Parse_Key'Result.Field_End = 0
            and then Parse_Key'Result.Character_Start = 1
            and then Parse_Key'Result.Character_End = 0);
end Posix_Tools.Text.Sort_Modifiers;
