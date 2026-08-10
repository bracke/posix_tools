with Posix_Tools.Commands.Tail;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Tail is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("tail", Posix_Tools.Commands.Tail.Run);
begin
   Main;
end Tail;
