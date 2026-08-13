with Posix_Tools.Commands.Rm;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Rm is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("rm", Posix_Tools.Commands.Rm.Run);
begin
   Main;
end Rm;
