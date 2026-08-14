with Posix_Tools.Commands.Timeout;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Timeout is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("timeout", Posix_Tools.Commands.Timeout.Run);
begin
   Main;
end Timeout;
