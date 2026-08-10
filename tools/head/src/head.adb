with Posix_Tools.Commands.Head;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Head is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("head", Posix_Tools.Commands.Head.Run);
begin
   Main;
end Head;
