with Posix_Tools.Commands.Getconf;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Getconf is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("getconf", Posix_Tools.Commands.Getconf.Run);
begin
   Main;
end Getconf;
