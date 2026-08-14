with Posix_Tools.Commands.Od;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Od is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("od", Posix_Tools.Commands.Od.Run);
begin
   Main;
end Od;
