package Posix_Tools.Text.Glob_Fields
  with SPARK_Mode => On
is
   function Bracket_Class_Matches
     (Pattern : String;
      Open    : Positive;
      Closing : Positive;
      Ch      : Character) return Boolean
   with
     Pre =>
       Pattern /= ""
       and then Open in Pattern'Range
       and then Closing in Pattern'Range
       and then Open < Closing
       and then Pattern (Open) = '['
       and then Pattern (Closing) = ']';

   function Closing_Bracket_From (Pattern : String; Open : Positive) return Natural
     with
       Pre =>
         Pattern /= ""
         and then Open in Pattern'Range
         and then Open < Pattern'Last
         and then Pattern (Open) = '[',
       Post =>
         Closing_Bracket_From'Result = 0
         or else Closing_Bracket_From'Result in Open + 1 .. Pattern'Last;
end Posix_Tools.Text.Glob_Fields;
