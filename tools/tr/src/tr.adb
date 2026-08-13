with Posix_Tools.Commands.Tr;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Tr is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("tr", Posix_Tools.Commands.Tr.Run);
begin
   Main;
end Tr;
