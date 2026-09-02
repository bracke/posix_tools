with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Awk_CLI.Diagnostics;

package Awk_CLI.Options is
   --  Deterministic POSIX-style command-line option parser.
   --
   --  Parser failures are returned explicitly as diagnostics rather than
   --  raised as ordinary operational exceptions.

   package U renames Ada.Strings.Unbounded;

   type Color_Mode is (Color_Auto, Color_Always, Color_Never);

   type Assignment is record
      Name           : U.Unbounded_String;
      Value          : U.Unbounded_String;
      Original_Index : Positive := 1;
      Original_Text  : U.Unbounded_String;
   end record;

   type Program_File is record
      Name           : U.Unbounded_String;
      Original_Index : Positive := 1;
   end record;

   type Operand is record
      Text           : U.Unbounded_String;
      Original_Index : Positive := 1;
   end record;

   package Assignment_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Assignment);
   package Program_File_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Program_File);
   package Operand_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Operand);

   type Parsed_Options is record
      Help_Requested    : Boolean := False;
      Version_Requested : Boolean := False;
      Color             : Color_Mode := Color_Auto;
      Has_Field_Separator : Boolean := False;
      Field_Separator   : U.Unbounded_String;
      Initial_Assignments : Assignment_Vectors.Vector;
      Program_Files     : Program_File_Vectors.Vector;
      Operands          : Operand_Vectors.Vector;
   end record;

   type Parse_Result (Ok : Boolean := False) is record
      case Ok is
         when True =>
            Options : Parsed_Options;
         when False =>
            Color      : Color_Mode := Color_Auto;
            Diagnostic : Awk_CLI.Diagnostics.Diagnostic;
      end case;
   end record;

   package String_Vectors renames Awk_CLI.String_Vectors;

   --  @param Arguments Raw process argument vector.
   --  @return Parsed options or a structured usage diagnostic.
   function Parse (Arguments : String_Vectors.Vector) return Parse_Result;

   --  @param Text Candidate assignment text.
   --  @return True when Text matches the CLI assignment-name grammar.
   function Is_Assignment_Text (Text : String) return Boolean;

   --  @param Text Assignment text containing '='.
   --  @param Name Name before the first '='.
   --  @param Value Complete value after the first '='.
   procedure Split_Assignment (Text : String; Name, Value : out U.Unbounded_String);
end Awk_CLI.Options;
