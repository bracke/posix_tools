with Posix_Tools.Commands.Logname;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Logname is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("logname", Posix_Tools.Commands.Logname.Run);
begin
   Main;
end Logname;
