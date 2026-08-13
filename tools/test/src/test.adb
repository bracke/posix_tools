with Posix_Tools.Commands.Test_Command;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Test is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("test", Posix_Tools.Commands.Test_Command.Run);
begin
   Main;
end Test;
