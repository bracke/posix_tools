with Posix_Tools.Commands.Pathchk;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Pathchk is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("pathchk", Posix_Tools.Commands.Pathchk.Run);
begin
   Main;
end Pathchk;
