with Posix_Tools.Commands.Hostname;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Hostname is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("hostname", Posix_Tools.Commands.Hostname.Run);
begin
   Main;
end Hostname;
