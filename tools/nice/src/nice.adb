with Posix_Tools.Commands.Nice;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Nice is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("nice", Posix_Tools.Commands.Nice.Run);
begin
   Main;
end Nice;
