with Posix_Tools.Commands.Split;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Split is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("split", Posix_Tools.Commands.Split.Run);
begin
   Main;
end Split;
