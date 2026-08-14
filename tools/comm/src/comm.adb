with Posix_Tools.Commands.Comm;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Comm is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("comm", Posix_Tools.Commands.Comm.Run);
begin
   Main;
end Comm;
