with Posix_Tools.Commands.Stat;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Stat is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("stat", Posix_Tools.Commands.Stat.Run);
begin
   Main;
end Stat;
