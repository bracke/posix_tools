with Posix_Tools.Commands.Mv;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Mv is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("mv", Posix_Tools.Commands.Mv.Run);
begin
   Main;
end Mv;
