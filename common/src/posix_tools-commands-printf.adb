with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Printf_Execution;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Printf is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Format_Ok    : Boolean := True;
      Arguments_Ok : Boolean := True;
   begin
      --  The first argument is the format and the rest its arguments, so the project
      --  extensions are recognized only as a sole argument.
      if Posix_Tools.Commands.Helpers.Intercept_Extension
        (Context, Result, Conventional => False)
      then
         return;
      end if;

      if Context.Argument_Count = 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      Posix_Tools.Commands.Printf_Execution.Execute
        (Context, Context.Argument (1), 2, Format_Ok, Arguments_Ok);

      if not Format_Ok then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Number);
         return;
      end if;

      Result.Status :=
        (if Context.Output_Failed or else not Arguments_Ok then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Printf;
