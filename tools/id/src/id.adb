with Posix_Tools.Commands.Id;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Id is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("id", Posix_Tools.Commands.Id.Run);
begin
   Main;
end Id;
