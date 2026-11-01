with Ada.Containers.Indefinite_Vectors;

--  The SET operands of tr: classes, equivalence classes, collating symbols,
--  ranges, repetitions and escapes expanded into the characters they stand
--  for. grep's bracket expressions use the byte form too.
package Posix_Tools.Commands.Text_Helpers.Tr_Sets is
   --  One element of a set: the bytes of one character. In the C and POSIX
   --  locales every byte is a character; elsewhere characters are UTF-8, and
   --  a byte that does not start a valid sequence is a character of its own.
   package Element_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   No_Code_Point : constant Long_Long_Integer := -1;

   --  The set operand Text as bytes: ranges run over byte values, and
   --  [c*n] repeats a byte.
   function Byte_Set (Text, Locale : String) return String;

   --  The set operand Text as characters, for a locale with multibyte
   --  characters: ranges run over code points, and [c*n] repeats a character.
   --  Classes, equivalence classes, collating symbols and escapes are
   --  expanded by Byte_Set.
   function Character_Set (Text, Locale : String) return Element_Vectors.Vector;

   --  The width of the character at Index and its code point (No_Code_Point
   --  for an invalid byte). Width is 0 when Text ends inside a sequence more
   --  input might complete, unless At_End.
   procedure Decode_At
     (Text       : String;
      Index      : Positive;
      At_End     : Boolean;
      Width      : out Natural;
      Code_Point : out Long_Long_Integer);

   --  The set operand Text as tr takes it in Locale: characters when
   --  Multibyte, else bytes.
   function Operand_Set (Text, Locale : String; Multibyte : Boolean) return Element_Vectors.Vector;

   --  Splits bytes into one-byte elements, or into characters.
   function Split (Text : String; Multibyte : Boolean) return Element_Vectors.Vector;
end Posix_Tools.Commands.Text_Helpers.Tr_Sets;
