with Posix_Tools.Commands.Paste;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Paste is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("paste", Posix_Tools.Commands.Paste.Run);
begin
   Main;
end Paste;
