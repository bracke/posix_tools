with Posix_Tools.Commands.Expand;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Expand is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("expand", Posix_Tools.Commands.Expand.Run);
begin
   Main;
end Expand;
