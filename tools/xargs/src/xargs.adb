with Posix_Tools.Commands.Xargs;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Xargs is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("xargs", Posix_Tools.Commands.Xargs.Run);
begin
   Main;
end Xargs;
