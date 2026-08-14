with Posix_Tools.Commands.Chown;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Chown is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("chown", Posix_Tools.Commands.Chown.Run);
begin
   Main;
end Chown;
