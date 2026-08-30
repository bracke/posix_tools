package body Posix_Tools.Command_Inventory.Tables
  with SPARK_Mode => On
is
   function Executable (Index : Positive) return String is
   begin
      case Index is
         when 1 =>
            return "arch";
         when 2 =>
            return "basename";
         when 3 =>
            return "cat";
         when 4 =>
            return "chgrp";
         when 5 =>
            return "chmod";
         when 6 =>
            return "chown";
         when 7 =>
            return "cksum";
         when 8 =>
            return "cmp";
         when 9 =>
            return "comm";
         when 10 =>
            return "cp";
         when 11 =>
            return "cut";
         when 12 =>
            return "date";
         when 13 =>
            return "dd";
         when 14 =>
            return "df";
         when 15 =>
            return "dirname";
         when 16 =>
            return "du";
         when 17 =>
            return "echo";
         when 18 =>
            return "env";
         when 19 =>
            return "expand";
         when 20 =>
            return "expr";
         when 21 =>
            return "false";
         when 22 =>
            return "file";
         when 23 =>
            return "find";
         when 24 =>
            return "fold";
         when 25 =>
            return "getconf";
         when 26 =>
            return "groups";
         when 27 =>
            return "head";
         when 28 =>
            return "hostname";
         when 29 =>
            return "id";
         when 30 =>
            return "kill";
         when 31 =>
            return "link";
         when 32 =>
            return "ln";
         when 33 =>
            return "locale";
         when 34 =>
            return "logname";
         when 35 =>
            return "ls";
         when 36 =>
            return "mkdir";
         when 37 =>
            return "mkfifo";
         when 38 =>
            return "mv";
         when 39 =>
            return "nice";
         when 40 =>
            return "nl";
         when 41 =>
            return "nohup";
         when 42 =>
            return "od";
         when 43 =>
            return "paste";
         when 44 =>
            return "pathchk";
         when 45 =>
            return "printenv";
         when 46 =>
            return "printf";
         when 47 =>
            return "pwd";
         when 48 =>
            return "readlink";
         when 49 =>
            return "realpath";
         when 50 =>
            return "rm";
         when 51 =>
            return "rmdir";
         when 52 =>
            return "seq";
         when 53 =>
            return "sha256sum";
         when 54 =>
            return "sleep";
         when 55 =>
            return "split";
         when 56 =>
            return "stat";
         when 57 =>
            return "sort";
         when 58 =>
            return "tail";
         when 59 =>
            return "tee";
         when 60 =>
            return "test";
         when 61 =>
            return "timeout";
         when 62 =>
            return "touch";
         when 63 =>
            return "tr";
         when 64 =>
            return "true";
         when 65 =>
            return "tty";
         when 66 =>
            return "unexpand";
         when 67 =>
            return "uname";
         when 68 =>
            return "unlink";
         when 69 =>
            return "uniq";
         when 70 =>
            return "wc";
         when 71 =>
            return "which";
         when 72 =>
            return "whoami";
         when 73 =>
            return "xargs";
         when 74 =>
            return "yes";
         when others =>
            raise Constraint_Error;
      end case;
   end Executable;

   function Crate (Index : Positive) return String is
   begin
      return "posix_tools_" & Executable (Index);
   end Crate;

   function Package_Name (Index : Positive) return String is
   begin
      case Index is
         when 1 =>
            return "Posix_Tools.Commands.Arch";
         when 2 =>
            return "Posix_Tools.Commands.Basename";
         when 3 =>
            return "Posix_Tools.Commands.Cat";
         when 4 =>
            return "Posix_Tools.Commands.Chgrp";
         when 5 =>
            return "Posix_Tools.Commands.Chmod";
         when 6 =>
            return "Posix_Tools.Commands.Chown";
         when 7 =>
            return "Posix_Tools.Commands.Cksum";
         when 8 =>
            return "Posix_Tools.Commands.Cmp";
         when 9 =>
            return "Posix_Tools.Commands.Comm";
         when 10 =>
            return "Posix_Tools.Commands.Cp";
         when 11 =>
            return "Posix_Tools.Commands.Cut";
         when 12 =>
            return "Posix_Tools.Commands.Date";
         when 13 =>
            return "Posix_Tools.Commands.Dd";
         when 14 =>
            return "Posix_Tools.Commands.Df";
         when 15 =>
            return "Posix_Tools.Commands.Dirname";
         when 16 =>
            return "Posix_Tools.Commands.Du";
         when 17 =>
            return "Posix_Tools.Commands.Echo";
         when 18 =>
            return "Posix_Tools.Commands.Env";
         when 19 =>
            return "Posix_Tools.Commands.Expand";
         when 20 =>
            return "Posix_Tools.Commands.Expr";
         when 21 =>
            return "Posix_Tools.Commands.False_Command";
         when 22 =>
            return "Posix_Tools.Commands.File";
         when 23 =>
            return "Posix_Tools.Commands.Find";
         when 24 =>
            return "Posix_Tools.Commands.Fold";
         when 25 =>
            return "Posix_Tools.Commands.Getconf";
         when 26 =>
            return "Posix_Tools.Commands.Groups";
         when 27 =>
            return "Posix_Tools.Commands.Head";
         when 28 =>
            return "Posix_Tools.Commands.Hostname";
         when 29 =>
            return "Posix_Tools.Commands.Id";
         when 30 =>
            return "Posix_Tools.Commands.Kill";
         when 31 =>
            return "Posix_Tools.Commands.Link";
         when 32 =>
            return "Posix_Tools.Commands.Ln";
         when 33 =>
            return "Posix_Tools.Commands.Locale";
         when 34 =>
            return "Posix_Tools.Commands.Logname";
         when 35 =>
            return "Posix_Tools.Commands.Ls";
         when 36 =>
            return "Posix_Tools.Commands.Mkdir";
         when 37 =>
            return "Posix_Tools.Commands.Mkfifo";
         when 38 =>
            return "Posix_Tools.Commands.Mv";
         when 39 =>
            return "Posix_Tools.Commands.Nice";
         when 40 =>
            return "Posix_Tools.Commands.Nl";
         when 41 =>
            return "Posix_Tools.Commands.Nohup";
         when 42 =>
            return "Posix_Tools.Commands.Od";
         when 43 =>
            return "Posix_Tools.Commands.Paste";
         when 44 =>
            return "Posix_Tools.Commands.Pathchk";
         when 45 =>
            return "Posix_Tools.Commands.Printenv";
         when 46 =>
            return "Posix_Tools.Commands.Printf";
         when 47 =>
            return "Posix_Tools.Commands.Pwd";
         when 48 =>
            return "Posix_Tools.Commands.Readlink";
         when 49 =>
            return "Posix_Tools.Commands.Realpath";
         when 50 =>
            return "Posix_Tools.Commands.Rm";
         when 51 =>
            return "Posix_Tools.Commands.Rmdir";
         when 52 =>
            return "Posix_Tools.Commands.Seq";
         when 53 =>
            return "Posix_Tools.Commands.Sha256sum";
         when 54 =>
            return "Posix_Tools.Commands.Sleep";
         when 55 =>
            return "Posix_Tools.Commands.Split";
         when 56 =>
            return "Posix_Tools.Commands.Stat";
         when 57 =>
            return "Posix_Tools.Commands.Sort";
         when 58 =>
            return "Posix_Tools.Commands.Tail";
         when 59 =>
            return "Posix_Tools.Commands.Tee";
         when 60 =>
            return "Posix_Tools.Commands.Test_Command";
         when 61 =>
            return "Posix_Tools.Commands.Timeout";
         when 62 =>
            return "Posix_Tools.Commands.Touch";
         when 63 =>
            return "Posix_Tools.Commands.Tr";
         when 64 =>
            return "Posix_Tools.Commands.True_Command";
         when 65 =>
            return "Posix_Tools.Commands.Tty";
         when 66 =>
            return "Posix_Tools.Commands.Unexpand";
         when 67 =>
            return "Posix_Tools.Commands.Uname";
         when 68 =>
            return "Posix_Tools.Commands.Unlink";
         when 69 =>
            return "Posix_Tools.Commands.Uniq";
         when 70 =>
            return "Posix_Tools.Commands.Wc";
         when 71 =>
            return "Posix_Tools.Commands.Which";
         when 72 =>
            return "Posix_Tools.Commands.Whoami";
         when 73 =>
            return "Posix_Tools.Commands.Xargs";
         when 74 =>
            return "Posix_Tools.Commands.Yes";
         when others =>
            raise Constraint_Error;
      end case;
   end Package_Name;

   function Posix_Status (Index : Positive) return String is
      pragma Unreferenced (Index);
   begin
      return "conforming_with_extensions";
   end Posix_Status;
end Posix_Tools.Command_Inventory.Tables;
