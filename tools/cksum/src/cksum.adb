with Posix_Tools.Commands.Cksum;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Cksum is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("cksum", Posix_Tools.Commands.Cksum.Run);
begin
   Main;
end Cksum;
