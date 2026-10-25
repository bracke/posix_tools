with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;

--  What a command executable does with a context the host has initialized:
--  run the command, and turn an exception escaping it into the localized
--  internal-failure diagnostic and status. Host_Adapters.Run_Command
--  instantiates it for each executable; tests instantiate it the same way
--  for their own contexts, so a command they run takes the production path.
generic
   Command_Name : String;
   with procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result);
procedure Posix_Tools.Commands.Run_Entry
  (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
   Result  : out Posix_Tools.Commands.Results.Result);
