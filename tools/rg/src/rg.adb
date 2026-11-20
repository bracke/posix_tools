with Posix_Tools.Commands.Rg;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Rg is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("rg", Posix_Tools.Commands.Rg.Run);
begin
   Main;
end Rg;
