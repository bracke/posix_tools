with Posix_Tools.Commands.Which;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Which is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("which", Posix_Tools.Commands.Which.Run);
begin
   Main;
end Which;
