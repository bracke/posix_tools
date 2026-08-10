with Posix_Tools.Commands.False_Command;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Posix_Tools_False_Main is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("false", Posix_Tools.Commands.False_Command.Run);
begin
   Main;
end Posix_Tools_False_Main;
