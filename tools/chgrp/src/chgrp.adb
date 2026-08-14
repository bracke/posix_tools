with Posix_Tools.Commands.Chgrp;
with Posix_Tools.Host_Adapters.Run_Command;

procedure Chgrp is
   procedure Main is new Posix_Tools.Host_Adapters.Run_Command
     ("chgrp", Posix_Tools.Commands.Chgrp.Run);
begin
   Main;
end Chgrp;
