with Explore.Application;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Explore_Main is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("explore", Explore.Application.Run);
begin
   Main;
end Explore_Main;
