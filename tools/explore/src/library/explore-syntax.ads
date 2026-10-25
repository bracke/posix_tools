with Ada.Containers.Vectors;
with Explore.String_Vectors;

--  Light syntax colouring for text previews: keywords, strings, comments,
--  and numbers in the languages a source tree is mostly made of, told apart
--  by the file's extension or its #! line. It is a tokenizer, not a parser;
--  a preview that is coloured a little wrong is still the file's text.
package Explore.Syntax is
   type Language is (No_Language, Ada_Language, C_Family, Hash_Commented, JSON_Language, Markdown_Language);

   --  The language of the file called Name whose first line is First_Line.
   function Language_Of (Name, First_Line : String) return Language;

   type Token_Kind is (Plain, Keyword, String_Literal, Comment, Number, Heading);

   type Span is record
      First, Last : Natural := 0;
      Kind        : Token_Kind := Plain;
   end record;

   package Span_Vectors is new Ada.Containers.Vectors (Positive, Span);

   --  Whether a block comment is open at the start of a line.
   type Line_State is record
      In_Block_Comment : Boolean := False;
   end record;

   --  The coloured runs of Line, by byte position, and the state the next
   --  line starts in. Bytes no span covers are plain.
   procedure Tokenize
     (Line        : String;
      Of_Language : Language;
      State       : in out Line_State;
      Spans       : out Span_Vectors.Vector);

   package Line_Span_Vectors is new Ada.Containers.Vectors (Positive, Span_Vectors.Vector, Span_Vectors."=");

   --  The coloured runs of each of Lines, in order, as Tokenize finds them
   --  from the first line on: what a preview is coloured with, worked out
   --  once when it is built rather than on every frame. None, for no
   --  language.
   function Tokenize_Lines
     (Lines       : Explore.String_Vectors.Vector;
      Of_Language : Language) return Line_Span_Vectors.Vector;
end Explore.Syntax;
