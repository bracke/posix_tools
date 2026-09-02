separate (Awk_CLI.Platform)
function Run_Command
  (Command : String;
   Output  : out U.Unbounded_String) return Boolean
is
begin
   return Command_Execution.Run_Command (Command, Output);
end Run_Command;
