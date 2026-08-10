with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;

generic
   Command_Name : String;
   with procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result);
procedure Posix_Tools.Host_Adapters.Run_Command;
