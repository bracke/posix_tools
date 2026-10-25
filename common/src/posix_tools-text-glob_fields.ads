--  The bracket expressions of a shell glob, "[a-z]" and "[!0-9]": finding
--  where one ends and whether a character is in it. Kept apart from
--  Posix_Tools.Text.Glob, which walks the rest of a pattern, so that these
--  index-heavy parts can be proved free of runtime errors on their own.
--  Despite its name, it has nothing to do with fields.
package Posix_Tools.Text.Glob_Fields
  with SPARK_Mode => On
is
   --  Whether Ch is a member of the bracket expression Pattern (Open ..
   --  Closing), brackets included: one of its characters or within one of
   --  its "a-z" ranges, or neither when it starts with '!' or '^'.
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

   --  Where the bracket expression opened at Open ends: the index of its
   --  closing ']', a ']' that comes first, after any negation, being one of
   --  its members. Zero when it is never closed, and the '[' is then an
   --  ordinary character.
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
