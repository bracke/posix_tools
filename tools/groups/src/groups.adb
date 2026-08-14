with Posix_Tools.Commands.Groups;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Groups is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("groups", Posix_Tools.Commands.Groups.Run);
begin
   Main;
end Groups;
