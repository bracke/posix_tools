with Posix_Tools.Exit_Status;

package Posix_Tools.Commands.Results is
   type Result is record
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;
end Posix_Tools.Commands.Results;
