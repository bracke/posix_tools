with Posix_Tools.Commands.Uname;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Uname is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("uname", Posix_Tools.Commands.Uname.Run);
begin
   Main;
end Uname;
