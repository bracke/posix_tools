package body Posix_Tools.Command_Inventory is
   type Command_Descriptor is record
      Executable    : access constant String;
      Crate         : access constant String;
      Package_Name  : access constant String;
      Posix_Status  : access constant String;
   end record;

   Basename_Exe : aliased constant String := "basename";
   Cat_Exe      : aliased constant String := "cat";
   Chgrp_Exe    : aliased constant String := "chgrp";
   Chmod_Exe    : aliased constant String := "chmod";
   Chown_Exe    : aliased constant String := "chown";
   Cksum_Exe    : aliased constant String := "cksum";
   Cmp_Exe      : aliased constant String := "cmp";
   Comm_Exe     : aliased constant String := "comm";
   Cp_Exe       : aliased constant String := "cp";
   Cut_Exe      : aliased constant String := "cut";
   Date_Exe     : aliased constant String := "date";
   Dd_Exe       : aliased constant String := "dd";
   Dirname_Exe  : aliased constant String := "dirname";
   Du_Exe       : aliased constant String := "du";
   Echo_Exe     : aliased constant String := "echo";
   Env_Exe      : aliased constant String := "env";
   Expand_Exe   : aliased constant String := "expand";
   Expr_Exe     : aliased constant String := "expr";
   False_Exe    : aliased constant String := "false";
   File_Exe     : aliased constant String := "file";
   Find_Exe     : aliased constant String := "find";
   Fold_Exe     : aliased constant String := "fold";
   Head_Exe     : aliased constant String := "head";
   Id_Exe       : aliased constant String := "id";
   Kill_Exe     : aliased constant String := "kill";
   Link_Exe     : aliased constant String := "link";
   Ln_Exe       : aliased constant String := "ln";
   Logname_Exe  : aliased constant String := "logname";
   Ls_Exe       : aliased constant String := "ls";
   Mkdir_Exe    : aliased constant String := "mkdir";
   Mv_Exe       : aliased constant String := "mv";
   Nl_Exe       : aliased constant String := "nl";
   Od_Exe       : aliased constant String := "od";
   Paste_Exe    : aliased constant String := "paste";
   Pathchk_Exe  : aliased constant String := "pathchk";
   Printf_Exe   : aliased constant String := "printf";
   Pwd_Exe      : aliased constant String := "pwd";
   Readlink_Exe : aliased constant String := "readlink";
   Realpath_Exe : aliased constant String := "realpath";
   Rm_Exe       : aliased constant String := "rm";
   Rmdir_Exe    : aliased constant String := "rmdir";
   Seq_Exe      : aliased constant String := "seq";
   Sleep_Exe    : aliased constant String := "sleep";
   Split_Exe    : aliased constant String := "split";
   Sort_Exe     : aliased constant String := "sort";
   Tail_Exe     : aliased constant String := "tail";
   Tee_Exe      : aliased constant String := "tee";
   Test_Exe     : aliased constant String := "test";
   Timeout_Exe  : aliased constant String := "timeout";
   Touch_Exe    : aliased constant String := "touch";
   Tr_Exe       : aliased constant String := "tr";
   True_Exe     : aliased constant String := "true";
   Tty_Exe      : aliased constant String := "tty";
   Unexpand_Exe : aliased constant String := "unexpand";
   Unlink_Exe   : aliased constant String := "unlink";
   Uname_Exe    : aliased constant String := "uname";
   Uniq_Exe     : aliased constant String := "uniq";
   Wc_Exe       : aliased constant String := "wc";
   Whoami_Exe   : aliased constant String := "whoami";
   Xargs_Exe    : aliased constant String := "xargs";

   Basename_Crate : aliased constant String := "posix_tools_basename";
   Cat_Crate      : aliased constant String := "posix_tools_cat";
   Chgrp_Crate    : aliased constant String := "posix_tools_chgrp";
   Chmod_Crate    : aliased constant String := "posix_tools_chmod";
   Chown_Crate    : aliased constant String := "posix_tools_chown";
   Cksum_Crate    : aliased constant String := "posix_tools_cksum";
   Cmp_Crate      : aliased constant String := "posix_tools_cmp";
   Comm_Crate     : aliased constant String := "posix_tools_comm";
   Cp_Crate       : aliased constant String := "posix_tools_cp";
   Cut_Crate      : aliased constant String := "posix_tools_cut";
   Date_Crate     : aliased constant String := "posix_tools_date";
   Dd_Crate       : aliased constant String := "posix_tools_dd";
   Dirname_Crate  : aliased constant String := "posix_tools_dirname";
   Du_Crate       : aliased constant String := "posix_tools_du";
   Echo_Crate     : aliased constant String := "posix_tools_echo";
   Env_Crate      : aliased constant String := "posix_tools_env";
   Expand_Crate   : aliased constant String := "posix_tools_expand";
   Expr_Crate     : aliased constant String := "posix_tools_expr";
   False_Crate    : aliased constant String := "posix_tools_false";
   File_Crate     : aliased constant String := "posix_tools_file";
   Find_Crate     : aliased constant String := "posix_tools_find";
   Fold_Crate     : aliased constant String := "posix_tools_fold";
   Head_Crate     : aliased constant String := "posix_tools_head";
   Id_Crate       : aliased constant String := "posix_tools_id";
   Kill_Crate     : aliased constant String := "posix_tools_kill";
   Link_Crate     : aliased constant String := "posix_tools_link";
   Ln_Crate       : aliased constant String := "posix_tools_ln";
   Logname_Crate  : aliased constant String := "posix_tools_logname";
   Ls_Crate       : aliased constant String := "posix_tools_ls";
   Mkdir_Crate    : aliased constant String := "posix_tools_mkdir";
   Mv_Crate       : aliased constant String := "posix_tools_mv";
   Nl_Crate       : aliased constant String := "posix_tools_nl";
   Od_Crate       : aliased constant String := "posix_tools_od";
   Paste_Crate    : aliased constant String := "posix_tools_paste";
   Pathchk_Crate  : aliased constant String := "posix_tools_pathchk";
   Printf_Crate   : aliased constant String := "posix_tools_printf";
   Pwd_Crate      : aliased constant String := "posix_tools_pwd";
   Readlink_Crate : aliased constant String := "posix_tools_readlink";
   Realpath_Crate : aliased constant String := "posix_tools_realpath";
   Rm_Crate       : aliased constant String := "posix_tools_rm";
   Rmdir_Crate    : aliased constant String := "posix_tools_rmdir";
   Seq_Crate      : aliased constant String := "posix_tools_seq";
   Sleep_Crate    : aliased constant String := "posix_tools_sleep";
   Split_Crate    : aliased constant String := "posix_tools_split";
   Sort_Crate     : aliased constant String := "posix_tools_sort";
   Tail_Crate     : aliased constant String := "posix_tools_tail";
   Tee_Crate      : aliased constant String := "posix_tools_tee";
   Test_Crate     : aliased constant String := "posix_tools_test";
   Timeout_Crate  : aliased constant String := "posix_tools_timeout";
   Touch_Crate    : aliased constant String := "posix_tools_touch";
   Tr_Crate       : aliased constant String := "posix_tools_tr";
   True_Crate     : aliased constant String := "posix_tools_true";
   Tty_Crate      : aliased constant String := "posix_tools_tty";
   Unexpand_Crate : aliased constant String := "posix_tools_unexpand";
   Unlink_Crate   : aliased constant String := "posix_tools_unlink";
   Uname_Crate    : aliased constant String := "posix_tools_uname";
   Uniq_Crate     : aliased constant String := "posix_tools_uniq";
   Wc_Crate       : aliased constant String := "posix_tools_wc";
   Whoami_Crate   : aliased constant String := "posix_tools_whoami";
   Xargs_Crate    : aliased constant String := "posix_tools_xargs";

   Basename_Pkg : aliased constant String := "Posix_Tools.Commands.Basename";
   Cat_Pkg      : aliased constant String := "Posix_Tools.Commands.Cat";
   Chgrp_Pkg    : aliased constant String := "Posix_Tools.Commands.Chgrp";
   Chmod_Pkg    : aliased constant String := "Posix_Tools.Commands.Chmod";
   Chown_Pkg    : aliased constant String := "Posix_Tools.Commands.Chown";
   Cksum_Pkg    : aliased constant String := "Posix_Tools.Commands.Cksum";
   Cmp_Pkg      : aliased constant String := "Posix_Tools.Commands.Cmp";
   Comm_Pkg     : aliased constant String := "Posix_Tools.Commands.Comm";
   Cp_Pkg       : aliased constant String := "Posix_Tools.Commands.Cp";
   Cut_Pkg      : aliased constant String := "Posix_Tools.Commands.Cut";
   Date_Pkg     : aliased constant String := "Posix_Tools.Commands.Date";
   Dd_Pkg       : aliased constant String := "Posix_Tools.Commands.Dd";
   Dirname_Pkg  : aliased constant String := "Posix_Tools.Commands.Dirname";
   Du_Pkg       : aliased constant String := "Posix_Tools.Commands.Du";
   Echo_Pkg     : aliased constant String := "Posix_Tools.Commands.Echo";
   Env_Pkg      : aliased constant String := "Posix_Tools.Commands.Env";
   Expand_Pkg   : aliased constant String := "Posix_Tools.Commands.Expand";
   Expr_Pkg     : aliased constant String := "Posix_Tools.Commands.Expr";
   False_Pkg    : aliased constant String := "Posix_Tools.Commands.False_Command";
   File_Pkg     : aliased constant String := "Posix_Tools.Commands.File";
   Find_Pkg     : aliased constant String := "Posix_Tools.Commands.Find";
   Fold_Pkg     : aliased constant String := "Posix_Tools.Commands.Fold";
   Head_Pkg     : aliased constant String := "Posix_Tools.Commands.Head";
   Id_Pkg       : aliased constant String := "Posix_Tools.Commands.Id";
   Kill_Pkg     : aliased constant String := "Posix_Tools.Commands.Kill";
   Link_Pkg     : aliased constant String := "Posix_Tools.Commands.Link";
   Ln_Pkg       : aliased constant String := "Posix_Tools.Commands.Ln";
   Logname_Pkg  : aliased constant String := "Posix_Tools.Commands.Logname";
   Ls_Pkg       : aliased constant String := "Posix_Tools.Commands.Ls";
   Mkdir_Pkg    : aliased constant String := "Posix_Tools.Commands.Mkdir";
   Mv_Pkg       : aliased constant String := "Posix_Tools.Commands.Mv";
   Nl_Pkg       : aliased constant String := "Posix_Tools.Commands.Nl";
   Od_Pkg       : aliased constant String := "Posix_Tools.Commands.Od";
   Paste_Pkg    : aliased constant String := "Posix_Tools.Commands.Paste";
   Pathchk_Pkg  : aliased constant String := "Posix_Tools.Commands.Pathchk";
   Printf_Pkg   : aliased constant String := "Posix_Tools.Commands.Printf";
   Pwd_Pkg      : aliased constant String := "Posix_Tools.Commands.Pwd";
   Readlink_Pkg : aliased constant String := "Posix_Tools.Commands.Readlink";
   Realpath_Pkg : aliased constant String := "Posix_Tools.Commands.Realpath";
   Rm_Pkg       : aliased constant String := "Posix_Tools.Commands.Rm";
   Rmdir_Pkg    : aliased constant String := "Posix_Tools.Commands.Rmdir";
   Seq_Pkg      : aliased constant String := "Posix_Tools.Commands.Seq";
   Sleep_Pkg    : aliased constant String := "Posix_Tools.Commands.Sleep";
   Split_Pkg    : aliased constant String := "Posix_Tools.Commands.Split";
   Sort_Pkg     : aliased constant String := "Posix_Tools.Commands.Sort";
   Tail_Pkg     : aliased constant String := "Posix_Tools.Commands.Tail";
   Tee_Pkg      : aliased constant String := "Posix_Tools.Commands.Tee";
   Test_Pkg     : aliased constant String := "Posix_Tools.Commands.Test_Command";
   Timeout_Pkg  : aliased constant String := "Posix_Tools.Commands.Timeout";
   Touch_Pkg    : aliased constant String := "Posix_Tools.Commands.Touch";
   Tr_Pkg       : aliased constant String := "Posix_Tools.Commands.Tr";
   True_Pkg     : aliased constant String := "Posix_Tools.Commands.True_Command";
   Tty_Pkg      : aliased constant String := "Posix_Tools.Commands.Tty";
   Unexpand_Pkg : aliased constant String := "Posix_Tools.Commands.Unexpand";
   Unlink_Pkg   : aliased constant String := "Posix_Tools.Commands.Unlink";
   Uname_Pkg    : aliased constant String := "Posix_Tools.Commands.Uname";
   Uniq_Pkg     : aliased constant String := "Posix_Tools.Commands.Uniq";
   Wc_Pkg       : aliased constant String := "Posix_Tools.Commands.Wc";
   Whoami_Pkg   : aliased constant String := "Posix_Tools.Commands.Whoami";
   Xargs_Pkg    : aliased constant String := "Posix_Tools.Commands.Xargs";

   Conforming_With_Extensions : aliased constant String := "conforming_with_extensions";
   Known_Deviation            : aliased constant String := "known_deviation";

   Inventory : constant array (Positive range 1 .. Command_Count) of Command_Descriptor :=
     [1  => (Basename_Exe'Access, Basename_Crate'Access, Basename_Pkg'Access, Conforming_With_Extensions'Access),
      2  => (Cat_Exe'Access, Cat_Crate'Access, Cat_Pkg'Access, Conforming_With_Extensions'Access),
      3  => (Chgrp_Exe'Access, Chgrp_Crate'Access, Chgrp_Pkg'Access, Conforming_With_Extensions'Access),
      4  => (Chmod_Exe'Access, Chmod_Crate'Access, Chmod_Pkg'Access, Conforming_With_Extensions'Access),
      5  => (Chown_Exe'Access, Chown_Crate'Access, Chown_Pkg'Access, Conforming_With_Extensions'Access),
      6  => (Cksum_Exe'Access, Cksum_Crate'Access, Cksum_Pkg'Access, Conforming_With_Extensions'Access),
      7  => (Cmp_Exe'Access, Cmp_Crate'Access, Cmp_Pkg'Access, Conforming_With_Extensions'Access),
      8  => (Comm_Exe'Access, Comm_Crate'Access, Comm_Pkg'Access, Conforming_With_Extensions'Access),
      9  => (Cp_Exe'Access, Cp_Crate'Access, Cp_Pkg'Access, Conforming_With_Extensions'Access),
      10 => (Cut_Exe'Access, Cut_Crate'Access, Cut_Pkg'Access, Conforming_With_Extensions'Access),
      11 => (Date_Exe'Access, Date_Crate'Access, Date_Pkg'Access, Conforming_With_Extensions'Access),
      12 => (Dd_Exe'Access, Dd_Crate'Access, Dd_Pkg'Access, Conforming_With_Extensions'Access),
      13 => (Dirname_Exe'Access, Dirname_Crate'Access, Dirname_Pkg'Access, Conforming_With_Extensions'Access),
      14 => (Du_Exe'Access, Du_Crate'Access, Du_Pkg'Access, Conforming_With_Extensions'Access),
      15 => (Echo_Exe'Access, Echo_Crate'Access, Echo_Pkg'Access, Conforming_With_Extensions'Access),
      16 => (Env_Exe'Access, Env_Crate'Access, Env_Pkg'Access, Conforming_With_Extensions'Access),
      17 => (Expand_Exe'Access, Expand_Crate'Access, Expand_Pkg'Access, Conforming_With_Extensions'Access),
      18 => (Expr_Exe'Access, Expr_Crate'Access, Expr_Pkg'Access, Conforming_With_Extensions'Access),
      19 => (False_Exe'Access, False_Crate'Access, False_Pkg'Access, Conforming_With_Extensions'Access),
      20 => (File_Exe'Access, File_Crate'Access, File_Pkg'Access, Conforming_With_Extensions'Access),
      21 => (Find_Exe'Access, Find_Crate'Access, Find_Pkg'Access, Conforming_With_Extensions'Access),
      22 => (Fold_Exe'Access, Fold_Crate'Access, Fold_Pkg'Access, Conforming_With_Extensions'Access),
      23 => (Head_Exe'Access, Head_Crate'Access, Head_Pkg'Access, Conforming_With_Extensions'Access),
      24 => (Id_Exe'Access, Id_Crate'Access, Id_Pkg'Access, Conforming_With_Extensions'Access),
      25 => (Kill_Exe'Access, Kill_Crate'Access, Kill_Pkg'Access, Conforming_With_Extensions'Access),
      26 => (Link_Exe'Access, Link_Crate'Access, Link_Pkg'Access, Conforming_With_Extensions'Access),
      27 => (Ln_Exe'Access, Ln_Crate'Access, Ln_Pkg'Access, Conforming_With_Extensions'Access),
      28 => (Logname_Exe'Access, Logname_Crate'Access, Logname_Pkg'Access, Conforming_With_Extensions'Access),
      29 => (Ls_Exe'Access, Ls_Crate'Access, Ls_Pkg'Access, Conforming_With_Extensions'Access),
      30 => (Mkdir_Exe'Access, Mkdir_Crate'Access, Mkdir_Pkg'Access, Conforming_With_Extensions'Access),
      31 => (Mv_Exe'Access, Mv_Crate'Access, Mv_Pkg'Access, Conforming_With_Extensions'Access),
      32 => (Nl_Exe'Access, Nl_Crate'Access, Nl_Pkg'Access, Known_Deviation'Access),
      33 => (Od_Exe'Access, Od_Crate'Access, Od_Pkg'Access, Conforming_With_Extensions'Access),
      34 => (Paste_Exe'Access, Paste_Crate'Access, Paste_Pkg'Access, Conforming_With_Extensions'Access),
      35 => (Pathchk_Exe'Access, Pathchk_Crate'Access, Pathchk_Pkg'Access, Conforming_With_Extensions'Access),
      36 => (Printf_Exe'Access, Printf_Crate'Access, Printf_Pkg'Access, Conforming_With_Extensions'Access),
      37 => (Pwd_Exe'Access, Pwd_Crate'Access, Pwd_Pkg'Access, Conforming_With_Extensions'Access),
      38 => (Readlink_Exe'Access, Readlink_Crate'Access, Readlink_Pkg'Access, Conforming_With_Extensions'Access),
      39 => (Realpath_Exe'Access, Realpath_Crate'Access, Realpath_Pkg'Access, Conforming_With_Extensions'Access),
      40 => (Rm_Exe'Access, Rm_Crate'Access, Rm_Pkg'Access, Conforming_With_Extensions'Access),
      41 => (Rmdir_Exe'Access, Rmdir_Crate'Access, Rmdir_Pkg'Access, Conforming_With_Extensions'Access),
      42 => (Seq_Exe'Access, Seq_Crate'Access, Seq_Pkg'Access, Conforming_With_Extensions'Access),
      43 => (Sleep_Exe'Access, Sleep_Crate'Access, Sleep_Pkg'Access, Conforming_With_Extensions'Access),
      44 => (Split_Exe'Access, Split_Crate'Access, Split_Pkg'Access, Conforming_With_Extensions'Access),
      45 => (Sort_Exe'Access, Sort_Crate'Access, Sort_Pkg'Access, Conforming_With_Extensions'Access),
      46 => (Tail_Exe'Access, Tail_Crate'Access, Tail_Pkg'Access, Conforming_With_Extensions'Access),
      47 => (Tee_Exe'Access, Tee_Crate'Access, Tee_Pkg'Access, Conforming_With_Extensions'Access),
      48 => (Test_Exe'Access, Test_Crate'Access, Test_Pkg'Access, Conforming_With_Extensions'Access),
      49 => (Timeout_Exe'Access, Timeout_Crate'Access, Timeout_Pkg'Access, Conforming_With_Extensions'Access),
      50 => (Touch_Exe'Access, Touch_Crate'Access, Touch_Pkg'Access, Conforming_With_Extensions'Access),
      51 => (Tr_Exe'Access, Tr_Crate'Access, Tr_Pkg'Access, Conforming_With_Extensions'Access),
      52 => (True_Exe'Access, True_Crate'Access, True_Pkg'Access, Conforming_With_Extensions'Access),
      53 => (Tty_Exe'Access, Tty_Crate'Access, Tty_Pkg'Access, Conforming_With_Extensions'Access),
      54 => (Unexpand_Exe'Access, Unexpand_Crate'Access, Unexpand_Pkg'Access, Conforming_With_Extensions'Access),
      55 => (Uname_Exe'Access, Uname_Crate'Access, Uname_Pkg'Access, Conforming_With_Extensions'Access),
      56 => (Unlink_Exe'Access, Unlink_Crate'Access, Unlink_Pkg'Access, Conforming_With_Extensions'Access),
      57 => (Uniq_Exe'Access, Uniq_Crate'Access, Uniq_Pkg'Access, Conforming_With_Extensions'Access),
      58 => (Wc_Exe'Access, Wc_Crate'Access, Wc_Pkg'Access, Conforming_With_Extensions'Access),
      59 => (Whoami_Exe'Access, Whoami_Crate'Access, Whoami_Pkg'Access, Conforming_With_Extensions'Access),
      60 => (Xargs_Exe'Access, Xargs_Crate'Access, Xargs_Pkg'Access, Conforming_With_Extensions'Access)];

   function Executable (Index : Positive) return String is
   begin
      return Inventory (Index).Executable.all;
   end Executable;

   function Crate (Index : Positive) return String is
   begin
      return Inventory (Index).Crate.all;
   end Crate;

   function Package_Name (Index : Positive) return String is
   begin
      return Inventory (Index).Package_Name.all;
   end Package_Name;

   function Manifest_Path (Index : Positive) return String is
   begin
      return "tools/" & Executable (Index) & "/alire.toml";
   end Manifest_Path;

   function Project_File_Path (Index : Positive) return String is
   begin
      return "tools/" & Executable (Index) & "/" & Crate (Index) & ".gpr";
   end Project_File_Path;

   function Documentation_Path (Index : Positive) return String is
   begin
      return "docs/commands/" & Executable (Index) & ".md";
   end Documentation_Path;

   function Release_Included (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Release_Included;

   function Posix_Status (Index : Positive) return String is
   begin
      return Inventory (Index).Posix_Status.all;
   end Posix_Status;

   function Has_Help (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Has_Help;

   function Has_Version (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Has_Version;

   function Has_Identity (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Has_Identity;

   function Contains_Executable (Name : String) return Boolean is
   begin
      for I in 1 .. Command_Count loop
         if Executable (I) = Name then
            return True;
         end if;
      end loop;

      return False;
   end Contains_Executable;
end Posix_Tools.Command_Inventory;
