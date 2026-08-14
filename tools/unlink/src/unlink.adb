with Posix_Tools.Commands.Unlink;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Unlink is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("unlink", Posix_Tools.Commands.Unlink.Run);
begin
   Main;
end Unlink;
