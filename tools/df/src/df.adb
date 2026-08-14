with Posix_Tools.Commands.Df;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Df is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("df", Posix_Tools.Commands.Df.Run);
begin
   Main;
end Df;
