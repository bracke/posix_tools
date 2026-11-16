with Posix_Tools.Host_Adapters.Arguments;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Run_Entry;
with Posix_Tools.Exit_Status;
with Posix_Tools.Process_Entry;

procedure Posix_Tools.Host_Adapters.Run_Command is
   procedure Run_Command_Entry is new Posix_Tools.Commands.Run_Entry (Command_Name, Run);

   Context : Posix_Tools.Commands.Contexts.Context;
   Result  : Posix_Tools.Commands.Results.Result;
begin
   Context.Initialize (Command_Name, Posix_Tools.Host_Adapters.Arguments.To_Vector);
   Run_Command_Entry (Context, Result);
   Posix_Tools.Process_Entry.Complete (Integer (Result.Status));
exception
   --  What fails before or after the command ran: reading the arguments or
   --  setting the status.
   when Occurrence : others =>
      Posix_Tools.Commands.Helpers.Report_Internal_Error
        (Context, Command_Name, Occurrence);
      Posix_Tools.Process_Entry.Complete
        (Integer (Posix_Tools.Exit_Status.Internal_Failure));
end Posix_Tools.Host_Adapters.Run_Command;
