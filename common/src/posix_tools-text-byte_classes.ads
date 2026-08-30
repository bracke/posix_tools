package Posix_Tools.Text.Byte_Classes
  with SPARK_Mode => On
is
   subtype ASCII_Decimal_Value is Natural range 0 .. 9;
   subtype ASCII_Octal_Value is Natural range 0 .. 7;
   subtype ASCII_Hex_Value is Natural range 0 .. 15;
   subtype ASCII_Lowercase_Index is Natural range 0 .. 25;

   function Is_Horizontal_Tab (Ch : Character) return Boolean is
     (Ch = Character'Val (9))
     with Post => Is_Horizontal_Tab'Result = (Ch = Character'Val (9));

   function Is_LF (Ch : Character) return Boolean is
     (Ch = Character'Val (10))
     with Post => Is_LF'Result = (Ch = Character'Val (10));

   function Is_Space (Ch : Character) return Boolean is
     (Ch = ' ')
     with Post => Is_Space'Result = (Ch = ' ');

   function Is_ASCII_Alphanumeric (Ch : Character) return Boolean is
     (Ch in '0' .. '9' or else Ch in 'A' .. 'Z' or else Ch in 'a' .. 'z')
     with
       Post =>
         Is_ASCII_Alphanumeric'Result =
           (Ch in '0' .. '9' or else Ch in 'A' .. 'Z' or else Ch in 'a' .. 'z');

   function Is_ASCII_Alpha (Ch : Character) return Boolean is
     (Ch in 'A' .. 'Z' or else Ch in 'a' .. 'z')
     with
       Post =>
         Is_ASCII_Alpha'Result =
           (Ch in 'A' .. 'Z' or else Ch in 'a' .. 'z');

   function Is_ASCII_Control (Ch : Character) return Boolean is
     (Character'Pos (Ch) < 32 or else Character'Pos (Ch) = 127)
     with
       Post =>
         Is_ASCII_Control'Result =
           (Character'Pos (Ch) < 32 or else Character'Pos (Ch) = 127);

   function Is_ASCII_Digit (Ch : Character) return Boolean is
     (Ch in '0' .. '9')
     with Post => Is_ASCII_Digit'Result = (Ch in '0' .. '9');

   function Is_ASCII_Octal_Digit (Ch : Character) return Boolean is
     (Ch in '0' .. '7')
     with Post => Is_ASCII_Octal_Digit'Result = (Ch in '0' .. '7');

   function ASCII_Digit_Value (Ch : Character) return ASCII_Decimal_Value is
     (Character'Pos (Ch) - Character'Pos ('0'))
     with
       Pre  => Is_ASCII_Digit (Ch),
       Post =>
         ASCII_Digit_Value'Result =
           Character'Pos (Ch) - Character'Pos ('0');

   function ASCII_Digit_Character (Value : ASCII_Decimal_Value) return Character is
     (Character'Val (Character'Pos ('0') + Value))
     with
       Post =>
         Is_ASCII_Digit (ASCII_Digit_Character'Result)
         and then ASCII_Digit_Value (ASCII_Digit_Character'Result) = Value;

   function ASCII_Octal_Digit_Value (Ch : Character) return ASCII_Octal_Value is
     (Character'Pos (Ch) - Character'Pos ('0'))
     with
       Pre  => Is_ASCII_Octal_Digit (Ch),
       Post =>
         ASCII_Octal_Digit_Value'Result =
           Character'Pos (Ch) - Character'Pos ('0');

   function ASCII_Octal_Digit_Character (Value : ASCII_Octal_Value) return Character is
     (Character'Val (Character'Pos ('0') + Value))
     with
       Post =>
         Is_ASCII_Octal_Digit (ASCII_Octal_Digit_Character'Result)
         and then ASCII_Octal_Digit_Value (ASCII_Octal_Digit_Character'Result) = Value;

   function Is_ASCII_Graph (Ch : Character) return Boolean is
     (Character'Pos (Ch) in 33 .. 126)
     with Post => Is_ASCII_Graph'Result = (Character'Pos (Ch) in 33 .. 126);

   function Is_ASCII_Lower (Ch : Character) return Boolean is
     (Ch in 'a' .. 'z')
     with Post => Is_ASCII_Lower'Result = (Ch in 'a' .. 'z');

   function ASCII_Lowercase_Character (Value : ASCII_Lowercase_Index) return Character is
     (Character'Val (Character'Pos ('a') + Value))
     with
       Post =>
         Is_ASCII_Lower (ASCII_Lowercase_Character'Result)
         and then
           Character'Pos (ASCII_Lowercase_Character'Result) =
             Character'Pos ('a') + Value;

   function Is_ASCII_Printable (Ch : Character) return Boolean is
     (Character'Pos (Ch) in 32 .. 126)
     with Post => Is_ASCII_Printable'Result = (Character'Pos (Ch) in 32 .. 126);

   function Is_ASCII_Punctuation (Ch : Character) return Boolean is
     (Character'Pos (Ch) in 33 .. 47
      or else Character'Pos (Ch) in 58 .. 64
      or else Character'Pos (Ch) in 91 .. 96
      or else Character'Pos (Ch) in 123 .. 126)
     with
       Post =>
         Is_ASCII_Punctuation'Result =
           (Character'Pos (Ch) in 33 .. 47
            or else Character'Pos (Ch) in 58 .. 64
            or else Character'Pos (Ch) in 91 .. 96
            or else Character'Pos (Ch) in 123 .. 126);

   function Is_ASCII_Upper (Ch : Character) return Boolean is
     (Ch in 'A' .. 'Z')
     with Post => Is_ASCII_Upper'Result = (Ch in 'A' .. 'Z');

   function To_ASCII_Upper (Ch : Character) return Character is
     (Character'Val (Character'Pos (Ch) - Character'Pos ('a') + Character'Pos ('A')))
     with
       Pre  => Is_ASCII_Lower (Ch),
       Post =>
         Is_ASCII_Upper (To_ASCII_Upper'Result)
         and then
           Character'Pos (To_ASCII_Upper'Result) =
             Character'Pos (Ch) - Character'Pos ('a') + Character'Pos ('A');

   function To_ASCII_Lower (Ch : Character) return Character is
     (Character'Val (Character'Pos (Ch) - Character'Pos ('A') + Character'Pos ('a')))
     with
       Pre  => Is_ASCII_Upper (Ch),
       Post =>
         Is_ASCII_Lower (To_ASCII_Lower'Result)
         and then
           Character'Pos (To_ASCII_Lower'Result) =
             Character'Pos (Ch) - Character'Pos ('A') + Character'Pos ('a');

   function Is_ASCII_Hex_Digit (Ch : Character) return Boolean is
     (Ch in '0' .. '9' or else Ch in 'A' .. 'F' or else Ch in 'a' .. 'f')
     with
       Post =>
         Is_ASCII_Hex_Digit'Result =
           (Ch in '0' .. '9' or else Ch in 'A' .. 'F' or else Ch in 'a' .. 'f');

   function Is_ASCII_Upper_Hex_Digit (Ch : Character) return Boolean is
     (Ch in 'A' .. 'F')
     with Post => Is_ASCII_Upper_Hex_Digit'Result = (Ch in 'A' .. 'F');

   function Is_ASCII_Lower_Hex_Digit (Ch : Character) return Boolean is
     (Ch in 'a' .. 'f')
     with Post => Is_ASCII_Lower_Hex_Digit'Result = (Ch in 'a' .. 'f');

   function ASCII_Hex_Digit_Value (Ch : Character) return ASCII_Hex_Value is
     ((if Ch in '0' .. '9' then Character'Pos (Ch) - Character'Pos ('0')
       elsif Ch in 'A' .. 'F' then 10 + Character'Pos (Ch) - Character'Pos ('A')
       else 10 + Character'Pos (Ch) - Character'Pos ('a')))
     with
       Pre  => Is_ASCII_Hex_Digit (Ch),
       Post =>
         (if Ch in '0' .. '9' then
            ASCII_Hex_Digit_Value'Result =
              Character'Pos (Ch) - Character'Pos ('0'))
         and then
           (if Ch in 'A' .. 'F' then
              ASCII_Hex_Digit_Value'Result =
                10 + Character'Pos (Ch) - Character'Pos ('A'))
         and then
           (if Ch in 'a' .. 'f' then
              ASCII_Hex_Digit_Value'Result =
                10 + Character'Pos (Ch) - Character'Pos ('a'));

   function ASCII_Hex_Digit_Character
     (Value : ASCII_Hex_Value;
      Upper : Boolean := False) return Character is
     ((if Value <= 9 then Character'Val (Character'Pos ('0') + Value)
       elsif Upper then Character'Val (Character'Pos ('A') + Value - 10)
       else Character'Val (Character'Pos ('a') + Value - 10)))
     with
       Post =>
         Is_ASCII_Hex_Digit (ASCII_Hex_Digit_Character'Result)
         and then ASCII_Hex_Digit_Value (ASCII_Hex_Digit_Character'Result) = Value
         and then
           (if Upper and then Value > 9 then
              Is_ASCII_Upper_Hex_Digit (ASCII_Hex_Digit_Character'Result))
         and then
           (if not Upper and then Value > 9 then
              Is_ASCII_Lower_Hex_Digit (ASCII_Hex_Digit_Character'Result));

   function Is_POSIX_Blank (Ch : Character) return Boolean is
     (Is_Space (Ch) or else Is_Horizontal_Tab (Ch))
     with
       Post =>
         Is_POSIX_Blank'Result =
           (Ch = ' ' or else Ch = Character'Val (9));

   function Is_POSIX_Space (Ch : Character) return Boolean is
     (Ch in ' ' | Character'Val (9) | Character'Val (10) | Character'Val (11) |
       Character'Val (12) | Character'Val (13))
     with
       Post =>
         Is_POSIX_Space'Result =
           (Ch in ' ' | Character'Val (9) | Character'Val (10) | Character'Val (11) |
             Character'Val (12) | Character'Val (13));

   function Is_Sort_Dictionary_Character (Ch : Character) return Boolean is
     (Is_ASCII_Alphanumeric (Ch) or else Is_POSIX_Blank (Ch))
     with
       Post =>
         Is_Sort_Dictionary_Character'Result =
           (Ch in '0' .. '9'
            or else Ch in 'A' .. 'Z'
            or else Ch in 'a' .. 'z'
            or else Ch = ' '
            or else Ch = Character'Val (9));

   function Is_Cut_List_Separator (Ch : Character) return Boolean is
     (Ch = ',' or else Is_POSIX_Blank (Ch))
     with
       Post =>
         Is_Cut_List_Separator'Result =
           (Ch = ',' or else Ch = ' ' or else Ch = Character'Val (9));

   function Is_Portable_Filename_Character (Ch : Character) return Boolean is
     (Is_ASCII_Alphanumeric (Ch) or else Ch = '.' or else Ch = '_' or else Ch = '-')
     with
       Post =>
         Is_Portable_Filename_Character'Result =
           (Ch in '0' .. '9'
            or else Ch in 'A' .. 'Z'
            or else Ch in 'a' .. 'z'
            or else Ch = '.'
            or else Ch = '_'
            or else Ch = '-');

   function Is_File_Text_Byte (Ch : Character) return Boolean is
     (Ch in Character'Val (9) | Character'Val (10) | Character'Val (12) |
       Character'Val (13)
      or else Is_ASCII_Printable (Ch))
     with
       Post =>
         Is_File_Text_Byte'Result =
           (Ch in Character'Val (9) | Character'Val (10) | Character'Val (12) |
             Character'Val (13)
            or else Character'Pos (Ch) in 32 .. 126);

   function Is_Xargs_Blank (Ch : Character) return Boolean is
     (Is_Space (Ch) or else Is_Horizontal_Tab (Ch) or else Is_LF (Ch))
     with
       Post =>
         Is_Xargs_Blank'Result =
           (Ch = ' ' or else Ch = Character'Val (9) or else Ch = Character'Val (10));
end Posix_Tools.Text.Byte_Classes;
