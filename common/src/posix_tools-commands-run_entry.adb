with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

procedure Posix_Tools.Commands.Run_Entry
  (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
   Result  : out Posix_Tools.Commands.Results.Result)
is
begin
   Run (Context, Result);
exception
   when Occurrence : others =>
      Result.Status := Posix_Tools.Exit_Status.Internal_Failure;
      Posix_Tools.Commands.Helpers.Report_Internal_Error
        (Context, Command_Name, Occurrence);
end Posix_Tools.Commands.Run_Entry;
