with Posix_Tools.Commands.Sleep;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Sleep is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("sleep", Posix_Tools.Commands.Sleep.Run);
begin
   Main;
end Sleep;
