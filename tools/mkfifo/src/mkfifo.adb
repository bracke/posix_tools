with Posix_Tools.Commands.Mkfifo;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Mkfifo is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("mkfifo", Posix_Tools.Commands.Mkfifo.Run);
begin
   Main;
end Mkfifo;
