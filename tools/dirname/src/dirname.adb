with Posix_Tools.Commands.Dirname;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Dirname is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("dirname", Posix_Tools.Commands.Dirname.Run);
begin
   Main;
end Dirname;
