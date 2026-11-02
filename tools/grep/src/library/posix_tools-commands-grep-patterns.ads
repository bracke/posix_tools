with Ada.Containers.Indefinite_Vectors;

--  The pattern lists grep searches for, and the translation of POSIX basic
--  regular expressions into the extended syntax greplib compiles.
package Posix_Tools.Commands.Grep.Patterns is
   package Text_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   --  Pattern, a basic regular expression, as the extended regular
   --  expression that matches the same text. Bracket ranges are expanded
   --  in the collation order of Locale, and equivalence classes and
   --  collating symbols are resolved in it.
   function Basic_To_Extended (Pattern : String; Locale : String) return String;

   --  Append to List each pattern of Text, the argument of -e or the
   --  pattern operand: the patterns are separated by newlines, so a text
   --  ending in a newline ends in an empty pattern, which matches every
   --  line.
   procedure Append_Pattern_List (List : in out Text_Vectors.Vector; Text : String);

   --  Append to List each pattern of Data, the bytes of a -f pattern file:
   --  one pattern a line, the last line's newline optional. An empty file
   --  adds no pattern; an empty line adds the empty pattern.
   procedure Append_Pattern_File (List : in out Text_Vectors.Vector; Data : String);
end Posix_Tools.Commands.Grep.Patterns;
