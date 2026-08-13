with Posix_Tools.Commands.Find;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Find is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("find", Posix_Tools.Commands.Find.Run);
begin
   Main;
end Find;
