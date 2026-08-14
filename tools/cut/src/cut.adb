with Posix_Tools.Commands.Cut;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Cut is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("cut", Posix_Tools.Commands.Cut.Run);
begin
   Main;
end Cut;
