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
            return "expr";
         when 22 =>
            return "false";
         when 23 =>
            return "file";
         when 24 =>
            return "find";
         when 25 =>
            return "fold";
         when 26 =>
            return "getconf";
         when 27 =>
            return "groups";
         when 28 =>
            return "grep";
         when 29 =>
            return "head";
         when 30 =>
            return "hostname";
         when 31 =>
            return "id";
         when 32 =>
            return "kill";
         when 33 =>
            return "link";
         when 34 =>
            return "ln";
         when 35 =>
            return "locale";
         when 36 =>
            return "logname";
         when 37 =>
            return "ls";
         when 38 =>
            return "mkdir";
         when 39 =>
            return "mkfifo";
         when 40 =>
            return "mv";
         when 41 =>
            return "nice";
         when 42 =>
            return "nl";
         when 43 =>
            return "nohup";
         when 44 =>
            return "od";
         when 45 =>
            return "paste";
         when 46 =>
            return "pathchk";
         when 47 =>
            return "printenv";
         when 48 =>
            return "printf";
         when 49 =>
            return "pwd";
         when 50 =>
            return "readlink";
         when 51 =>
            return "realpath";
         when 52 =>
            return "rm";
         when 53 =>
            return "rmdir";
         when 54 =>
            return "seq";
         when 55 =>
            return "sed";
         when 56 =>
            return "sha256sum";
         when 57 =>
            return "sleep";
         when 58 =>
            return "split";
         when 59 =>
            return "stat";
         when 60 =>
            return "sort";
         when 61 =>
            return "tail";
         when 62 =>
            return "tee";
         when 63 =>
            return "test";
         when 64 =>
            return "timeout";
         when 65 =>
            return "touch";
         when 66 =>
            return "tr";
         when 67 =>
            return "true";
         when 68 =>
            return "tty";
         when 69 =>
            return "unexpand";
         when 70 =>
            return "uname";
         when 71 =>
            return "unlink";
         when 72 =>
            return "uniq";
         when 73 =>
            return "wc";
         when 74 =>
            return "which";
         when 75 =>
            return "whoami";
         when 76 =>
            return "xargs";
         when 77 =>
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
            return "Posix_Tools.Commands.Expr";
         when 22 =>
            return "Posix_Tools.Commands.False_Command";
         when 23 =>
            return "Posix_Tools.Commands.File";
         when 24 =>
            return "Posix_Tools.Commands.Find";
         when 25 =>
            return "Posix_Tools.Commands.Fold";
         when 26 =>
            return "Posix_Tools.Commands.Getconf";
         when 27 =>
            return "Posix_Tools.Commands.Groups";
         when 28 =>
            return "Greplib";
         when 29 =>
            return "Posix_Tools.Commands.Head";
         when 30 =>
            return "Posix_Tools.Commands.Hostname";
         when 31 =>
            return "Posix_Tools.Commands.Id";
         when 32 =>
            return "Posix_Tools.Commands.Kill";
         when 33 =>
            return "Posix_Tools.Commands.Link";
         when 34 =>
            return "Posix_Tools.Commands.Ln";
         when 35 =>
            return "Posix_Tools.Commands.Locale";
         when 36 =>
            return "Posix_Tools.Commands.Logname";
         when 37 =>
            return "Posix_Tools.Commands.Ls";
         when 38 =>
            return "Posix_Tools.Commands.Mkdir";
         when 39 =>
            return "Posix_Tools.Commands.Mkfifo";
         when 40 =>
            return "Posix_Tools.Commands.Mv";
         when 41 =>
            return "Posix_Tools.Commands.Nice";
         when 42 =>
            return "Posix_Tools.Commands.Nl";
         when 43 =>
            return "Posix_Tools.Commands.Nohup";
         when 44 =>
            return "Posix_Tools.Commands.Od";
         when 45 =>
            return "Posix_Tools.Commands.Paste";
         when 46 =>
            return "Posix_Tools.Commands.Pathchk";
         when 47 =>
            return "Posix_Tools.Commands.Printenv";
         when 48 =>
            return "Posix_Tools.Commands.Printf";
         when 49 =>
            return "Posix_Tools.Commands.Pwd";
         when 50 =>
            return "Posix_Tools.Commands.Readlink";
         when 51 =>
            return "Posix_Tools.Commands.Realpath";
         when 52 =>
            return "Posix_Tools.Commands.Rm";
         when 53 =>
            return "Posix_Tools.Commands.Rmdir";
         when 54 =>
            return "Posix_Tools.Commands.Seq";
         when 55 =>
            return "Sed";
         when 56 =>
            return "Posix_Tools.Commands.Sha256sum";
         when 57 =>
            return "Posix_Tools.Commands.Sleep";
         when 58 =>
            return "Posix_Tools.Commands.Split";
         when 59 =>
            return "Posix_Tools.Commands.Stat";
         when 60 =>
            return "Posix_Tools.Commands.Sort";
         when 61 =>
            return "Posix_Tools.Commands.Tail";
         when 62 =>
            return "Posix_Tools.Commands.Tee";
         when 63 =>
            return "Posix_Tools.Commands.Test_Command";
         when 64 =>
            return "Posix_Tools.Commands.Timeout";
         when 65 =>
            return "Posix_Tools.Commands.Touch";
         when 66 =>
            return "Posix_Tools.Commands.Tr";
         when 67 =>
            return "Posix_Tools.Commands.True_Command";
         when 68 =>
            return "Posix_Tools.Commands.Tty";
         when 69 =>
            return "Posix_Tools.Commands.Unexpand";
         when 70 =>
            return "Posix_Tools.Commands.Uname";
         when 71 =>
            return "Posix_Tools.Commands.Unlink";
         when 72 =>
            return "Posix_Tools.Commands.Uniq";
         when 73 =>
            return "Posix_Tools.Commands.Wc";
         when 74 =>
            return "Posix_Tools.Commands.Which";
         when 75 =>
            return "Posix_Tools.Commands.Whoami";
         when 76 =>
            return "Posix_Tools.Commands.Xargs";
         when 77 =>
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
