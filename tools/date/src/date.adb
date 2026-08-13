with Posix_Tools.Commands.Date;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Date is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("date", Posix_Tools.Commands.Date.Run);
begin
   Main;
end Date;
