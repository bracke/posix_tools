with Posix_Tools.Commands.Root;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Posix_Tools_Main is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("posix-tools", Posix_Tools.Commands.Root.Run);
begin
   Main;
end Posix_Tools_Main;
