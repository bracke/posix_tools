with Posix_Tools.Commands.Printf;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Printf is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("printf", Posix_Tools.Commands.Printf.Run);
begin
   Main;
end Printf;
