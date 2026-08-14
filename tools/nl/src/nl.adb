with Posix_Tools.Commands.Nl;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Nl is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("nl", Posix_Tools.Commands.Nl.Run);
begin
   Main;
end Nl;
