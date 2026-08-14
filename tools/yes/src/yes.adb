with Posix_Tools.Commands.Yes;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Yes is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("yes", Posix_Tools.Commands.Yes.Run);
begin
   Main;
end Yes;
