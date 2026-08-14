with Posix_Tools.Commands.Chmod;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Chmod is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("chmod", Posix_Tools.Commands.Chmod.Run);
begin
   Main;
end Chmod;
