with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Awk_CLI.Diagnostics;
with Awk_CLI.Operands;
with Awk_CLI.Platform;

package Awk_CLI.Inputs is
   --  Input materialization for named files and standard input.
   --
   --  This package owns host input loading only; AWK record and field behavior
   --  remains in awklib.

   package U renames Ada.Strings.Unbounded;

   type Input_File is record
      Name    : U.Unbounded_String;
      Content : U.Unbounded_String;
   end record;

   package Input_File_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Input_File);

   type Load_Result (Ok : Boolean := False) is record
      case Ok is
         when True =>
            Files : Input_File_Vectors.Vector;
         when False =>
            Diagnostic : Awk_CLI.Diagnostics.Diagnostic;
      end case;
   end record;

   --  @param Operands Classified input and assignment operands.
   --  @param Stdin Complete standard-input text.
   --  @param Read_File Host file reader callback.
   --  @param Path Input file path passed to Read_File.
   --  @param Content Input file content returned by Read_File.
   --  @return Loaded input files or a structured diagnostic.
   function Load
     (Operands  : Awk_CLI.Operands.Operand_Vectors.Vector;
      Stdin     : String;
      Read_File : not null access function
        (Path : String; Content : out U.Unbounded_String) return Awk_CLI.Platform.Read_Status)
      return Load_Result;
end Awk_CLI.Inputs;
