with Ada.Command_Line;
with Posix_Tools.Host_Adapters.Arguments;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Run_Entry;
with Posix_Tools.Exit_Status;
with Posix_Tools.Localization;

procedure Posix_Tools.Host_Adapters.Run_Command is
   procedure Run_Command_Entry is new Posix_Tools.Commands.Run_Entry (Command_Name, Run);

   Context : Posix_Tools.Commands.Contexts.Context;
   Result  : Posix_Tools.Commands.Results.Result;
begin
   Context.Initialize (Command_Name, Posix_Tools.Host_Adapters.Arguments.To_Vector);
   Run_Command_Entry (Context, Result);
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (Result.Status));
exception
   --  What fails before or after the command ran: reading the arguments or
   --  setting the status.
   when others =>
      Context.Put_Error_Line
        (Command_Name & ": "
         & Posix_Tools.Localization.Text
             (Context.Effective_Locale,
              "posix_tools.diagnostic.internal_failure",
              "internal failure"));
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status (Posix_Tools.Exit_Status.Internal_Failure));
end Posix_Tools.Host_Adapters.Run_Command;
