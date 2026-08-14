with Posix_Tools.Commands.Kill;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Kill is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("kill", Posix_Tools.Commands.Kill.Run);
begin
   Main;
end Kill;
