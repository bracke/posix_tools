with Posix_Tools.Commands.Du;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Du is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("du", Posix_Tools.Commands.Du.Run);
begin
   Main;
end Du;
