with Posix_Tools.Commands.Link;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Link is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("link", Posix_Tools.Commands.Link.Run);
begin
   Main;
end Link;
