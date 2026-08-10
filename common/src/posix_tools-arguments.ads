with Ada.Containers.Indefinite_Vectors;

package Posix_Tools.Arguments is
   package Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   subtype Vector is Vectors.Vector;

   function Empty return Vector;
end Posix_Tools.Arguments;
