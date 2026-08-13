with Posix_Tools.Commands.Tee;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Tee is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("tee", Posix_Tools.Commands.Tee.Run);
begin
   Main;
end Tee;
