with Posix_Tools.Commands.Basename;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Basename is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("basename", Posix_Tools.Commands.Basename.Run);
begin
   Main;
end Basename;
