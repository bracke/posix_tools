with Posix_Tools.Commands.Pwd;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Pwd is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("pwd", Posix_Tools.Commands.Pwd.Run);
begin
   Main;
end Pwd;
