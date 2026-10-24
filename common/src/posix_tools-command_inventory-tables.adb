package body Posix_Tools.Command_Inventory.Tables
  with SPARK_Mode => On
is
   function Executable (Index : Positive) return String is
   begin
      case Index is
         when 1 =>
            return "arch";
         when 2 =>
            return "awk";
         when 3 =>
            return "basename";
         when 4 =>
            return "cat";
         when 5 =>
            return "chgrp";
         when 6 =>
            return "chmod";
         when 7 =>
            return "chown";
         when 8 =>
            return "cksum";
         when 9 =>
            return "cmp";
         when 10 =>
            return "comm";
         when 11 =>
            return "cp";
         when 12 =>
            return "cut";
         when 13 =>
            return "date";
         when 14 =>
            return "dd";
         when 15 =>
            return "df";
         when 16 =>
            return "dirname";
         when 17 =>
            return "du";
         when 18 =>
            return "echo";
         when 19 =>
            return "env";
         when 20 =>
            return "expand";
         when 21 =>
            return "explore";
         when 22 =>
            return "expr";
         when 23 =>
            return "false";
         when 24 =>
            return "file";
         when 25 =>
            return "find";
         when 26 =>
            return "fold";
         when 27 =>
            return "getconf";
         when 28 =>
            return "groups";
         when 29 =>
            return "grep";
         when 30 =>
            return "head";
         when 31 =>
            return "hostname";
         when 32 =>
            return "id";
         when 33 =>
            return "kill";
         when 34 =>
            return "link";
         when 35 =>
            return "ln";
         when 36 =>
            return "locale";
         when 37 =>
            return "logname";
         when 38 =>
            return "ls";
         when 39 =>
            return "mkdir";
         when 40 =>
            return "mkfifo";
         when 41 =>
            return "mv";
         when 42 =>
            return "nice";
         when 43 =>
            return "nl";
         when 44 =>
            return "nohup";
         when 45 =>
            return "od";
         when 46 =>
            return "paste";
         when 47 =>
            return "pathchk";
         when 48 =>
            return "printenv";
         when 49 =>
            return "printf";
         when 50 =>
            return "pwd";
         when 51 =>
            return "readlink";
         when 52 =>
            return "realpath";
         when 53 =>
            return "rm";
         when 54 =>
            return "rmdir";
         when 55 =>
            return "seq";
         when 56 =>
            return "sed";
         when 57 =>
            return "sha256sum";
         when 58 =>
            return "sleep";
         when 59 =>
            return "split";
         when 60 =>
            return "stat";
         when 61 =>
            return "sort";
         when 62 =>
            return "tail";
         when 63 =>
            return "tee";
         when 64 =>
            return "test";
         when 65 =>
            return "timeout";
         when 66 =>
            return "touch";
         when 67 =>
            return "tr";
         when 68 =>
            return "true";
         when 69 =>
            return "tty";
         when 70 =>
            return "unexpand";
         when 71 =>
            return "uname";
         when 72 =>
            return "unlink";
         when 73 =>
            return "uniq";
         when 74 =>
            return "wc";
         when 75 =>
            return "which";
         when 76 =>
            return "whoami";
         when 77 =>
            return "xargs";
         when 78 =>
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
            return "Awk_CLI";
         when 3 =>
            return "Posix_Tools.Commands.Basename";
         when 4 =>
            return "Posix_Tools.Commands.Cat";
         when 5 =>
            return "Posix_Tools.Commands.Chgrp";
         when 6 =>
            return "Posix_Tools.Commands.Chmod";
         when 7 =>
            return "Posix_Tools.Commands.Chown";
         when 8 =>
            return "Posix_Tools.Commands.Cksum";
         when 9 =>
            return "Posix_Tools.Commands.Cmp";
         when 10 =>
            return "Posix_Tools.Commands.Comm";
         when 11 =>
            return "Posix_Tools.Commands.Cp";
         when 12 =>
            return "Posix_Tools.Commands.Cut";
         when 13 =>
            return "Posix_Tools.Commands.Date";
         when 14 =>
            return "Posix_Tools.Commands.Dd";
         when 15 =>
            return "Posix_Tools.Commands.Df";
         when 16 =>
            return "Posix_Tools.Commands.Dirname";
         when 17 =>
            return "Posix_Tools.Commands.Du";
         when 18 =>
            return "Posix_Tools.Commands.Echo";
         when 19 =>
            return "Posix_Tools.Commands.Env";
         when 20 =>
            return "Posix_Tools.Commands.Expand";
         when 21 =>
            return "Explore";
         when 22 =>
            return "Posix_Tools.Commands.Expr";
         when 23 =>
            return "Posix_Tools.Commands.False_Command";
         when 24 =>
            return "Posix_Tools.Commands.File";
         when 25 =>
            return "Posix_Tools.Commands.Find";
         when 26 =>
            return "Posix_Tools.Commands.Fold";
         when 27 =>
            return "Posix_Tools.Commands.Getconf";
         when 28 =>
            return "Posix_Tools.Commands.Groups";
         when 29 =>
            return "Greplib";
         when 30 =>
            return "Posix_Tools.Commands.Head";
         when 31 =>
            return "Posix_Tools.Commands.Hostname";
         when 32 =>
            return "Posix_Tools.Commands.Id";
         when 33 =>
            return "Posix_Tools.Commands.Kill";
         when 34 =>
            return "Posix_Tools.Commands.Link";
         when 35 =>
            return "Posix_Tools.Commands.Ln";
         when 36 =>
            return "Posix_Tools.Commands.Locale";
         when 37 =>
            return "Posix_Tools.Commands.Logname";
         when 38 =>
            return "Posix_Tools.Commands.Ls";
         when 39 =>
            return "Posix_Tools.Commands.Mkdir";
         when 40 =>
            return "Posix_Tools.Commands.Mkfifo";
         when 41 =>
            return "Posix_Tools.Commands.Mv";
         when 42 =>
            return "Posix_Tools.Commands.Nice";
         when 43 =>
            return "Posix_Tools.Commands.Nl";
         when 44 =>
            return "Posix_Tools.Commands.Nohup";
         when 45 =>
            return "Posix_Tools.Commands.Od";
         when 46 =>
            return "Posix_Tools.Commands.Paste";
         when 47 =>
            return "Posix_Tools.Commands.Pathchk";
         when 48 =>
            return "Posix_Tools.Commands.Printenv";
         when 49 =>
            return "Posix_Tools.Commands.Printf";
         when 50 =>
            return "Posix_Tools.Commands.Pwd";
         when 51 =>
            return "Posix_Tools.Commands.Readlink";
         when 52 =>
            return "Posix_Tools.Commands.Realpath";
         when 53 =>
            return "Posix_Tools.Commands.Rm";
         when 54 =>
            return "Posix_Tools.Commands.Rmdir";
         when 55 =>
            return "Posix_Tools.Commands.Seq";
         when 56 =>
            return "Sed";
         when 57 =>
            return "Posix_Tools.Commands.Sha256sum";
         when 58 =>
            return "Posix_Tools.Commands.Sleep";
         when 59 =>
            return "Posix_Tools.Commands.Split";
         when 60 =>
            return "Posix_Tools.Commands.Stat";
         when 61 =>
            return "Posix_Tools.Commands.Sort";
         when 62 =>
            return "Posix_Tools.Commands.Tail";
         when 63 =>
            return "Posix_Tools.Commands.Tee";
         when 64 =>
            return "Posix_Tools.Commands.Test_Command";
         when 65 =>
            return "Posix_Tools.Commands.Timeout";
         when 66 =>
            return "Posix_Tools.Commands.Touch";
         when 67 =>
            return "Posix_Tools.Commands.Tr";
         when 68 =>
            return "Posix_Tools.Commands.True_Command";
         when 69 =>
            return "Posix_Tools.Commands.Tty";
         when 70 =>
            return "Posix_Tools.Commands.Unexpand";
         when 71 =>
            return "Posix_Tools.Commands.Uname";
         when 72 =>
            return "Posix_Tools.Commands.Unlink";
         when 73 =>
            return "Posix_Tools.Commands.Uniq";
         when 74 =>
            return "Posix_Tools.Commands.Wc";
         when 75 =>
            return "Posix_Tools.Commands.Which";
         when 76 =>
            return "Posix_Tools.Commands.Whoami";
         when 77 =>
            return "Posix_Tools.Commands.Xargs";
         when 78 =>
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
