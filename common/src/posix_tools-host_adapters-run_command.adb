with Ada.Command_Line;
with Posix_Tools.Host_Adapters.Arguments;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;
with Posix_Tools.Exit_Status;
with Posix_Tools.Localization;

procedure Posix_Tools.Host_Adapters.Run_Command is
   Context : Posix_Tools.Commands.Contexts.Context;
   Result  : Posix_Tools.Commands.Results.Result;
begin
   Context.Initialize (Command_Name, Posix_Tools.Host_Adapters.Arguments.To_Vector);
   Run (Context, Result);
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Exit_Status (Result.Status));
exception
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
