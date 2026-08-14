with Posix_Tools.Commands.Sha256sum;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Sha256sum is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("sha256sum", Posix_Tools.Commands.Sha256sum.Run);
begin
   Main;
end Sha256sum;
