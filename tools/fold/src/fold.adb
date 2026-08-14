with Posix_Tools.Commands.Fold;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Fold is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("fold", Posix_Tools.Commands.Fold.Run);
begin
   Main;
end Fold;
