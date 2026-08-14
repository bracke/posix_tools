with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;

package Posix_Tools.Commands.Expanded is
   type Expanded_Command is
     (Chgrp_Command,
      Chmod_Command,
      Chown_Command,
      Cksum_Command,
      Cmp_Command,
      Comm_Command,
      Cp_Command,
      Cut_Command,
      Date_Command,
      Dd_Command,
      Du_Command,
      Env_Command,
      Expr_Command,
      File_Command,
      Find_Command,
      Fold_Command,
      Id_Command,
      Kill_Command,
      Link_Command,
      Ln_Command,
      Logname_Command,
      Ls_Command,
      Mkdir_Command,
      Mv_Command,
      Od_Command,
      Paste_Command,
      Pathchk_Command,
      Printf_Command,
      Readlink_Command,
      Realpath_Command,
      Rm_Command,
      Rmdir_Command,
      Sleep_Command,
      Split_Command,
      Sort_Command,
      Tee_Command,
      Test_Command,
      Timeout_Command,
      Touch_Command,
      Tr_Command,
      Tty_Command,
      Uniq_Command,
      Uname_Command,
      Whoami_Command,
      Xargs_Command);

   procedure Run
     (Command : Expanded_Command;
      Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result);
end Posix_Tools.Commands.Expanded;
