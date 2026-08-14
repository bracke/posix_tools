with Posix_Tools.Commands.Seq;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Seq is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("seq", Posix_Tools.Commands.Seq.Run);
begin
   Main;
end Seq;
