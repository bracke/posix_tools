with Posix_Tools.Commands.Wc;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Wc is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("wc", Posix_Tools.Commands.Wc.Run);
begin
   Main;
end Wc;
