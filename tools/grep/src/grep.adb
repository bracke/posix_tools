with Posix_Tools.Commands.Grep;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Grep is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("grep", Posix_Tools.Commands.Grep.Run);
begin
   Main;
end Grep;
