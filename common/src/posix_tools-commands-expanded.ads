with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;

package Posix_Tools.Commands.Expanded is
   type Expanded_Command is
     (Cp_Command,
      Date_Command,
      Dd_Command,
      Env_Command,
      Find_Command,
      Ln_Command,
      Mkdir_Command,
      Mv_Command,
      Printf_Command,
      Rm_Command,
      Rmdir_Command,
      Sort_Command,
      Tee_Command,
      Test_Command,
      Touch_Command,
      Tr_Command,
      Uniq_Command,
      Xargs_Command);

   procedure Run
     (Command : Expanded_Command;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result);
end Posix_Tools.Commands.Expanded;
