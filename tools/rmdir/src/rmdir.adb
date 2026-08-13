with Posix_Tools.Commands.Rmdir;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Rmdir is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("rmdir", Posix_Tools.Commands.Rmdir.Run);
begin
   Main;
end Rmdir;
