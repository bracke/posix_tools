with Ada.Command_Line;

package body Posix_Tools.Host_Adapters.Arguments is
   function To_Vector return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         Result.Append (Ada.Command_Line.Argument (I));
      end loop;

      return Result;
   end To_Vector;
end Posix_Tools.Host_Adapters.Arguments;
