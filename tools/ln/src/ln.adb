with Posix_Tools.Commands.Ln;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Ln is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("ln", Posix_Tools.Commands.Ln.Run);
begin
   Main;
end Ln;
