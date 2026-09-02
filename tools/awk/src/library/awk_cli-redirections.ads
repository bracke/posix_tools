with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Awk_CLI.Diagnostics;

package Awk_CLI.Redirections is
   --  Host-side materialization of redirected AWK output.
   --
   --  Content is written exactly as produced by awklib and is never localized
   --  or styled here.

   package U renames Ada.Strings.Unbounded;

   type Write_Status is (Write_Success, Open_Failed, Write_Failed);

   type Redirected_Output is record
      Path    : U.Unbounded_String;
      Content : U.Unbounded_String;
      Append  : Boolean := False;
   end record;

   package Redirection_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Redirected_Output);

   type Materialize_Result (Ok : Boolean := True) is record
      case Ok is
         when True =>
            null;
         when False =>
            Diagnostic : Awk_CLI.Diagnostics.Diagnostic;
      end case;
   end record;

   --  @param Outputs Captured redirected outputs from awklib.
   --  @param Write_File Host file writer callback.
   --  @param Path Redirection path passed to Write_File.
   --  @param Content Redirection content passed to Write_File.
   --  @param Append Append mode passed to Write_File.
   --  @return Success or the first structured output diagnostic.
   function Materialize
     (Outputs    : Redirection_Vectors.Vector;
      Write_File : not null access function
        (Path : String; Content : String; Append : Boolean) return Write_Status)
      return Materialize_Result;
end Awk_CLI.Redirections;
