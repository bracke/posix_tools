with Posix_Tools.Commands.Realpath;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Realpath is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("realpath", Posix_Tools.Commands.Realpath.Run);
begin
   Main;
end Realpath;
