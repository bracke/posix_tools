with Posix_Tools.Commands.Nohup;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Nohup is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("nohup", Posix_Tools.Commands.Nohup.Run);
begin
   Main;
end Nohup;
