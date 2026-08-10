with Posix_Tools.Commands.Cat;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Cat is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("cat", Posix_Tools.Commands.Cat.Run);
begin
   Main;
end Cat;
