with Posix_Tools.Commands.Uniq;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Uniq is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("uniq", Posix_Tools.Commands.Uniq.Run);
begin
   Main;
end Uniq;
