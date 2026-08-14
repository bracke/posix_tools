with Posix_Tools.Commands.Printenv;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Printenv is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("printenv", Posix_Tools.Commands.Printenv.Run);
begin
   Main;
end Printenv;
