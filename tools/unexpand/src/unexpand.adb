with Posix_Tools.Commands.Unexpand;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Unexpand is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("unexpand", Posix_Tools.Commands.Unexpand.Run);
begin
   Main;
end Unexpand;
