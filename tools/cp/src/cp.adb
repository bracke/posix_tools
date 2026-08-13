with Posix_Tools.Commands.Cp;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Cp is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("cp", Posix_Tools.Commands.Cp.Run);
begin
   Main;
end Cp;
