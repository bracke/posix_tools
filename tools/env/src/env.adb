with Posix_Tools.Commands.Env;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Env is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("env", Posix_Tools.Commands.Env.Run);
begin
   Main;
end Env;
