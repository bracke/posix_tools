with Posix_Tools.Commands.True_Command;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Posix_Tools_True_Main is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("true", Posix_Tools.Commands.True_Command.Run);
begin
   Main;
end Posix_Tools_True_Main;
