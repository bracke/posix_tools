with Ada.Containers.Vectors;

package Posix_Tools.Commands.Text_Helpers.Tab_Stops is
   type Configuration is private;

   function Next_Column
     (Config : Configuration;
      Column : Natural) return Natural;

   function Parse
     (Config : in out Configuration;
      Text   : String) return Boolean;

   function Spaces_To_Next_Tab
     (Config : Configuration;
      Column : Natural) return Natural;

private
   package Stop_Vectors is new Ada.Containers.Vectors (Positive, Natural);

   type Configuration is record
      Default_Stop : Natural := 8;
      Stops        : Stop_Vectors.Vector;
   end record;
end Posix_Tools.Commands.Text_Helpers.Tab_Stops;
