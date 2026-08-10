with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.True_Command is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension
        (Context, Result, Conventional => False)
      then
         return;
      end if;

      Result.Status := Posix_Tools.Exit_Status.Success;
   end Run;
end Posix_Tools.Commands.True_Command;
