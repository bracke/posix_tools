with Posix_Tools.Commands.Touch;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Touch is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("touch", Posix_Tools.Commands.Touch.Run);
begin
   Main;
end Touch;
