with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Awk_CLI.Diagnostics;
with Awk_CLI.Options;
with Awk_CLI.Platform;

package Awk_CLI.Programs is
   --  AWK program source resolution.
   --
   --  This package chooses direct source versus -f files and concatenates
   --  source segments. It never parses or rewrites AWK source.

   package U renames Ada.Strings.Unbounded;

   type Source_Segment is record
      Display_Name : U.Unbounded_String;
      Start_Line   : Positive := 1;
      End_Line     : Natural := 0;
   end record;

   package Segment_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Source_Segment);

   type Program_Source is record
      Text     : U.Unbounded_String;
      Segments : Segment_Vectors.Vector;
      Operands : Awk_CLI.Options.Operand_Vectors.Vector;
   end record;

   type Resolve_Result (Ok : Boolean := False) is record
      case Ok is
         when True =>
            Source : Program_Source;
         when False =>
            Diagnostic : Awk_CLI.Diagnostics.Diagnostic;
      end case;
   end record;

   --  @param Options Parsed command-line options and operands.
   --  @param Read_File Host program-file reader callback.
   --  @param Path Program file path passed to Read_File.
   --  @param Content Program file content returned by Read_File.
   --  @return Resolved program source or a structured diagnostic.
   function Resolve
     (Options   : Awk_CLI.Options.Parsed_Options;
      Read_File : not null access function
        (Path : String; Content : out U.Unbounded_String) return Awk_CLI.Platform.Read_Status)
      return Resolve_Result;
end Awk_CLI.Programs;
