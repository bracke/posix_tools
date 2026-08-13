with Posix_Tools.Commands.Dd;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Dd is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("dd", Posix_Tools.Commands.Dd.Run);
begin
   Main;
end Dd;
