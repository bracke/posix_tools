with Posix_Tools.Commands.Whoami;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Whoami is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("whoami", Posix_Tools.Commands.Whoami.Run);
begin
   Main;
end Whoami;
