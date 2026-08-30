with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Printf_Execution;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Printf is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Format_Ok : Boolean := True;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count = 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      Posix_Tools.Commands.Printf_Execution.Execute
        (Context, Context.Argument (1), 2, Format_Ok);

      if not Format_Ok then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid number");
         return;
      end if;

      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Printf;
