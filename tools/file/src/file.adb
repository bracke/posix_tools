with Posix_Tools.Commands.File;
with Posix_Tools.Host_Adapters.Run_Command;

procedure File is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("file", Posix_Tools.Commands.File.Run);
begin
   Main;
end File;
