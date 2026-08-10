with Posix_Tools.Commands.Echo;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Echo is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("echo", Posix_Tools.Commands.Echo.Run);
begin
   Main;
end Echo;
