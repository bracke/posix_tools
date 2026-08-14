with Posix_Tools.Commands.Ls;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Ls is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("ls", Posix_Tools.Commands.Ls.Run);
begin
   Main;
end Ls;
