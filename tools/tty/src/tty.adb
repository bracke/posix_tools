with Posix_Tools.Commands.Tty;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Tty is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("tty", Posix_Tools.Commands.Tty.Run);
begin
   Main;
end Tty;
