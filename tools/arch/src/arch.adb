with Posix_Tools.Commands.Arch;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Arch is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("arch", Posix_Tools.Commands.Arch.Run);
begin
   Main;
end Arch;
