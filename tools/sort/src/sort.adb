with Posix_Tools.Commands.Sort;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Sort is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("sort", Posix_Tools.Commands.Sort.Run);
begin
   Main;
end Sort;
