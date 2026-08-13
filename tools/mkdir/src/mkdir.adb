with Posix_Tools.Commands.Mkdir;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Mkdir is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("mkdir", Posix_Tools.Commands.Mkdir.Run);
begin
   Main;
end Mkdir;
