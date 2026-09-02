with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Awk_CLI.Environment is
   --  Environment entry representation and normalization for ENVIRON setup.

   package U renames Ada.Strings.Unbounded;

   type Env_Entry is record
      Name  : U.Unbounded_String;
      Value : U.Unbounded_String;
   end record;

   package Entry_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Env_Entry);

   --  @param Entries Raw environment entries.
   --  @return Normalized environment entries.
   function Normalize (Entries : Entry_Vectors.Vector) return Entry_Vectors.Vector;
end Awk_CLI.Environment;
