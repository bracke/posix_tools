with Posix_Tools.Commands.Cmp;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Cmp is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("cmp", Posix_Tools.Commands.Cmp.Run);
begin
   Main;
end Cmp;
