with Posix_Tools.Commands.Readlink;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Readlink is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("readlink", Posix_Tools.Commands.Readlink.Run);
begin
   Main;
end Readlink;
