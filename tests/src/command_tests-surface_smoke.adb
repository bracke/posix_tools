with Ada.Calendar;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Command_Tests.Surface_Smoke.Helpers;
with GNAT.OS_Lib;
with Hostkit.Fs;
with Hostkit.Metadata;
with Posix_Tools.Commands.Arch;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Chgrp;
with Posix_Tools.Commands.Chmod;
with Posix_Tools.Commands.Chown;
with Posix_Tools.Commands.Cksum;
with Posix_Tools.Commands.Cmp;
with Posix_Tools.Commands.Comm;
with Posix_Tools.Commands.Cp;
with Posix_Tools.Commands.Cut;
with Posix_Tools.Commands.Date;
with Posix_Tools.Commands.Dd;
with Posix_Tools.Commands.Df;
with Posix_Tools.Commands.Env;
with Posix_Tools.Commands.Find;
with Posix_Tools.Commands.Getconf;
with Posix_Tools.Commands.Groups;
with Posix_Tools.Commands.Hostname;
with Posix_Tools.Commands.Id;
with Posix_Tools.Commands.Kill;
with Posix_Tools.Commands.Link;
with Posix_Tools.Commands.Ln;
with Posix_Tools.Commands.Locale;
with Posix_Tools.Commands.Logname;
with Posix_Tools.Commands.Ls;
with Posix_Tools.Commands.Mkdir;
with Posix_Tools.Commands.Mkfifo;
with Posix_Tools.Commands.Mv;
with Posix_Tools.Commands.Nice;
with Posix_Tools.Commands.Nohup;
with Posix_Tools.Commands.Od;
with Posix_Tools.Commands.Paste;
with Posix_Tools.Commands.Printenv;
with Posix_Tools.Commands.Printf;
with Posix_Tools.Commands.Readlink;
with Posix_Tools.Commands.Realpath;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rm;
with Posix_Tools.Commands.Rmdir;
with Posix_Tools.Commands.Sha256sum;
with Posix_Tools.Commands.Sleep;
with Posix_Tools.Commands.Split;
with Posix_Tools.Commands.Sort;
with Posix_Tools.Commands.Stat;
with Posix_Tools.Commands.Tee;
with Posix_Tools.Commands.Test_Command;
with Posix_Tools.Commands.Touch;
with Posix_Tools.Commands.Tr;
with Posix_Tools.Commands.Uname;
with Posix_Tools.Commands.Uniq;
with Posix_Tools.Commands.Which;
with Posix_Tools.Commands.Whoami;
with Posix_Tools.Commands.Xargs;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Signals;
with Test_Contexts;

package body Command_Tests.Surface_Smoke is
   use type Ada.Directories.File_Size;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Fs.Special_File_Kind;
   use type Posix_Tools.Host_Adapters.Signals.Disposition;
   use type Posix_Tools.Exit_Status.Code;
   use Ada.Strings.Unbounded;
   use Command_Tests.Surface_Smoke.Helpers;

   procedure Test_Command_Surface_Smoke (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Ada.Calendar.Time;
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Source  : constant String := Fixture_Path ("command-source.txt");
      Target  : constant String := Fixture_Path ("command-target.txt");
      Large_Source : constant String := Fixture_Path ("command-large-source.bin");
      Large_Target : constant String := Fixture_Path ("command-large-target.bin");
      Dash_Target : constant String := Fixture_Path ("command-dash-target.txt");
      Linked  : constant String := Fixture_Path ("command-linked.txt");
      Link_Command_Target : constant String := Fixture_Path ("command-link-command.txt");
      Symlinked : constant String := Fixture_Path ("command-symlinked.txt");
      Cp_Symlinked : constant String := Fixture_Path ("command-cp-symlinked.txt");
      Link_Dir : constant String := Fixture_Path ("command-ln-dir");
      Moved   : constant String := Fixture_Path ("command-moved.txt");
      Made    : constant String := Fixture_Path ("command-dir");
      Mkfifo_Target : constant String := Fixture_Path ("command-fifo");
      Symbolic_Mode_Dir : constant String := Fixture_Path ("command-symbolic-mode-dir");
      Relative_Mode_Dir : constant String := Fixture_Path ("command-relative-mode-dir");
      Remove_Dir : constant String := Fixture_Path ("command-rm-dir");
      Rm_Interactive : constant String := Fixture_Path ("command-rm-interactive.txt");
      Multi   : constant String := Fixture_Path ("command-multi");
      Other   : constant String := Fixture_Path ("command-other.txt");
      Tree    : constant String := Fixture_Path ("command-tree");
      Tree_Copy : constant String := Fixture_Path ("command-tree-copy");
      Sort_Out : constant String := Fixture_Path ("command-sort-output.txt");
      Empty   : constant String := Fixture_Path ("command-empty");
      Cp_Directory_Source : constant String := Fixture_Path ("command-cp-directory-source");
      Cp_Directory_Target : constant String := Fixture_Path ("command-cp-directory-target");
      Cp_FIFO_Source : constant String := Fixture_Path ("command-cp-fifo-source");
      Cp_FIFO_Target : constant String := Fixture_Path ("command-cp-fifo-target");
      Cp_Socket_Source : constant String := Fixture_Path ("command-cp-socket-source");
      Cp_Socket_Target : constant String := Fixture_Path ("command-cp-socket-target");
      Parent_Block : constant String := Fixture_Path ("command-parent-block");
      Option_Dir : constant String := Fixture_Path ("command-option-operands");
      Touched : constant String := Fixture_Path ("command-touch.txt");
      No_Create : constant String := Fixture_Path ("command-no-create.txt");
      Tee_Out : constant String := Fixture_Path ("command-tee.txt");
      Chmod_Target : constant String := Fixture_Path ("command-chmod.txt");
      Cksum_File : constant String := Fixture_Path ("command-cksum.txt");
      Cmp_First : constant String := Fixture_Path ("command-cmp-first.txt");
      Cmp_Second : constant String := Fixture_Path ("command-cmp-second.txt");
      Paste_First : constant String := Fixture_Path ("command-paste-first.txt");
      Paste_Second : constant String := Fixture_Path ("command-paste-second.txt");
      Cut_File : constant String := Fixture_Path ("command-cut.txt");
      Comm_First : constant String := Fixture_Path ("command-comm-first.txt");
      Comm_Second : constant String := Fixture_Path ("command-comm-second.txt");
      Od_File : constant String := Fixture_Path ("command-od.bin");
      Ls_Dir : constant String := Fixture_Path ("command-ls-dir");
      Ls_Other_Dir : constant String := Fixture_Path ("command-ls-other-dir");
      Split_Input : constant String := Fixture_Path ("command-split.txt");
      Split_Prefix : constant String := Fixture_Path ("command-split-out-");
      Split_Long_Prefix : constant String := Fixture_Path ("command-split-long-");
      Large_Hash_Input : constant String (1 .. 20_000) := [others => 'x'];
      EOL     : constant Character := Character'Val (10);

      procedure Remove_Any (Path : String) is
      begin
         if Hostkit.Fs.Is_Link (Path) then
            AUnit.Assertions.Assert (Hostkit.Fs.Delete_Link (Path), "cleanup link failed for " & Path);
         elsif Ada.Directories.Exists (Path) then
            if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
               Ada.Directories.Delete_Tree (Path);
            else
               declare
                  Deleted : Boolean := False;
               begin
                  GNAT.OS_Lib.Delete_File (Path, Deleted);
                  if not Deleted then
                     Ada.Directories.Delete_File (Path);
                  end if;
               end;
            end if;
         end if;
      exception
         when others =>
            AUnit.Assertions.Assert (False, "cleanup failed for " & Path);
      end Remove_Any;

      procedure Assert_Mode_When_Available (Path : String; Expected : Natural; Label : String) is
         Available : Boolean;
         Actual    : constant Natural := Hostkit.Metadata.File_Permission_Bits (Path, Available);
      begin
         if Hostkit.Metadata.Permissions_Supported and then Available then
            AUnit.Assertions.Assert (Actual mod 8#1000# = Expected, Label);
         end if;
      end Assert_Mode_When_Available;

      procedure Assert_Full_Mode_When_Available (Path : String; Expected : Natural; Label : String) is
         Available : Boolean;
         Actual    : constant Natural := Hostkit.Metadata.File_Permission_Bits (Path, Available);
      begin
         if Hostkit.Metadata.Permissions_Supported and then Available then
            AUnit.Assertions.Assert (Actual mod 8#10000# = Expected, Label);
         end if;
      end Assert_Full_Mode_When_Available;

      function Time_Near (Actual, Expected : Ada.Calendar.Time) return Boolean is
         Difference : constant Duration := Actual - Expected;
      begin
         return abs Difference <= 2.0;
      end Time_Near;

      function Large_Copy_Data return String is
         Data : String (1 .. 70 * 1024);
      begin
         for I in Data'Range loop
            Data (I) := Character'Val ((I - Data'First) mod 256);
         end loop;

         return Data;
      end Large_Copy_Data;

      function Trim_Natural (Value : Natural) return String is
      begin
         return Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left);
      end Trim_Natural;
   begin
      Remove_Any (Source);
      Remove_Any (Target);
      Remove_Any (Large_Source);
      Remove_Any (Large_Target);
      Remove_Any (Dash_Target);
      Remove_Any (Linked);
      Remove_Any (Link_Command_Target);
      Remove_Any (Symlinked);
      Remove_Any (Cp_Symlinked);
      Remove_Any (Link_Dir);
      Remove_Any (Moved);
      Remove_Any (Made);
      Remove_Any (Mkfifo_Target);
      Remove_Any (Symbolic_Mode_Dir);
      Remove_Any (Relative_Mode_Dir);
      Remove_Any (Remove_Dir);
      Remove_Any (Rm_Interactive);
      Remove_Any (Multi);
      Remove_Any (Other);
      Remove_Any (Tree);
      Remove_Any (Tree_Copy);
      Remove_Any (Sort_Out);
      Remove_Any (Empty);
      Remove_Any (Cp_Directory_Source);
      Remove_Any (Cp_Directory_Target);
      Remove_Any (Cp_FIFO_Source);
      Remove_Any (Cp_FIFO_Target);
      Remove_Any (Cp_Socket_Source);
      Remove_Any (Cp_Socket_Target);
      Remove_Any (Parent_Block);
      Remove_Any (Option_Dir);
      Remove_Any (Touched);
      Remove_Any (No_Create);
      Remove_Any (Tee_Out);
      Remove_Any (Chmod_Target);
      Remove_Any (Cksum_File);
      Remove_Any (Cmp_First);
      Remove_Any (Cmp_Second);
      Remove_Any (Paste_First);
      Remove_Any (Paste_Second);
      Remove_Any (Cut_File);
      Remove_Any (Comm_First);
      Remove_Any (Comm_Second);
      Remove_Any (Od_File);
      Remove_Any (Ls_Dir);
      Remove_Any (Ls_Other_Dir);
      Remove_Any (Split_Input);
      Remove_Any (Split_Prefix & "aa");
      Remove_Any (Split_Prefix & "ab");
      Remove_Any (Split_Long_Prefix & "aaa");
      Remove_Any (Split_Long_Prefix & "aab");
      Remove_Any (Split_Long_Prefix & "aac");

      Write_File (Source, "copy-data");
      Context.Initialize ("cp", Two_Args (Source, Target));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp status");

      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "copy-data", "cp copied data");

      declare
         Data : constant String := Large_Copy_Data;
      begin
         Write_File (Large_Source, Data);
         Context.Initialize ("cp", Two_Args (Large_Source, Large_Target));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "REG-CP-0001 cp copies large binary file");

         Context.Initialize ("cat", One_Arg (Large_Target));
         Posix_Tools.Commands.Cat.Run (Context, Result);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Data,
            "REG-CP-0001 cp preserves large binary file bytes");
      end;

      Ada.Directories.Create_Directory (Option_Dir);
      Ada.Directories.Create_Directory (Hostkit.Fs.Join (Option_Dir, "copies"));
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "plain-data");
      Write_File (Hostkit.Fs.Join (Option_Dir, "-v"), "dash-data");
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);
         Context.Initialize ("cp", Three_Args ("plain", "-v", "copies"));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Hostkit.Fs.Join (Hostkit.Fs.Join (Option_Dir, "copies"), "plain"))
         and then Ada.Directories.Exists (Hostkit.Fs.Join (Hostkit.Fs.Join (Option_Dir, "copies"), "-v")),
         "cp treats option-like words after first operand as operands");

      Context.Initialize ("cp", Two_Args (Source, Source));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "same file"),
         "cp rejects same source and destination");

      Ada.Directories.Create_Directory (Cp_Directory_Source);
      Context.Initialize ("cp", Two_Args (Cp_Directory_Source, Cp_Directory_Target));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "is a directory"),
         "cp diagnoses non-recursive directory source");

      Remove_Any (Linked);
      if Hostkit.Fs.Create_Hard_Link (Source, Linked) then
         Context.Initialize ("cp", Two_Args (Source, Linked));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
            and then Contains (Test_Contexts.Error_Output (Context), "same file"),
            "cp rejects destination hard link to source");
         Remove_Any (Linked);
      end if;

      if Hostkit.Fs.Create_Link (Source, Symlinked) then
         declare
            Target_Text : Unbounded_String;
         begin
            Remove_Any (Target);
            Context.Initialize ("cp", Three_Args ("-P", Symlinked, Cp_Symlinked));
            Posix_Tools.Commands.Cp.Run (Context, Result);
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success
               and then Hostkit.Fs.Is_Link (Cp_Symlinked)
               and then Hostkit.Fs.Read_Link_Target (Cp_Symlinked, Target_Text)
               and then To_String (Target_Text) = Source,
               "cp -P copies symbolic link itself");

            Remove_Any (Symlinked);
            Remove_Any (Cp_Symlinked);
         end;
      end if;

      if Hostkit.Metadata.Permissions_Supported then
         declare
            Access_Epoch       : constant Long_Long_Integer := 1_612_325_106;
            Modification_Epoch : constant Long_Long_Integer := 1_646_370_367;
         begin
            AUnit.Assertions.Assert
              (Hostkit.Metadata.Set_File_Times (Source, Access_Epoch, Modification_Epoch),
               "test source time setup");
         end;
         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Source, 8#640#),
            "test source mode setup");
         Remove_Any (Target);
         Context.Initialize ("cp", Three_Args ("-p", Source, Target));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp -p status");
         Assert_Mode_When_Available (Target, 8#640#, "cp -p preserves source mode");
         AUnit.Assertions.Assert
           (Time_Near (Ada.Directories.Modification_Time (Target), Ada.Directories.Modification_Time (Source)),
            "cp -p preserves source modification time");
         declare
            Source_Access_Available : Boolean;
            Target_Access_Available : Boolean;
            Source_Access   : constant Ada.Calendar.Time :=
              Hostkit.Metadata.File_Access_Time (Source, Source_Access_Available);
            Target_Access : constant Ada.Calendar.Time :=
              Hostkit.Metadata.File_Access_Time (Target, Target_Access_Available);
         begin
            if Source_Access_Available and then Target_Access_Available then
               AUnit.Assertions.Assert
                 (Time_Near (Target_Access, Source_Access),
                  "cp -p preserves source access time");
            end if;
         end;
         declare
            Source_User      : Natural;
            Source_Group     : Natural;
            Source_Available : Boolean;
            Target_User      : Natural;
            Target_Group     : Natural;
            Target_Available : Boolean;
         begin
            Hostkit.Metadata.File_Ownership (Source, Source_User, Source_Group, Source_Available);
            Hostkit.Metadata.File_Ownership (Target, Target_User, Target_Group, Target_Available);
            if Hostkit.Metadata.Ownership_Supported and then Source_Available and then Target_Available then
               AUnit.Assertions.Assert
                 (Source_User = Target_User and then Source_Group = Target_Group,
                  "cp -p preserves source ownership when available");
            end if;
         end;
         Write_File (Source, "copy-data");
      end if;

      Context.Initialize ("cp", Two_Args ("-", Dash_Target));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cp treats - as missing file operand");

      if Ada.Directories.Exists ("/dev/null")
        and then Ada.Directories.Kind ("/dev/null") = Ada.Directories.Special_File
      then
         Context.Initialize ("cp", Two_Args ("/dev/null", Target));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "cp reports portable special file creation failure");
      end if;

      if Hostkit.Fs.Create_FIFO (Cp_FIFO_Source, 8#600#) then
         Context.Initialize ("cp", Two_Args (Cp_FIFO_Source, Cp_FIFO_Target));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         declare
            Info : constant Hostkit.Fs.Special_File_Info := Hostkit.Fs.Special_File_Info_Of (Cp_FIFO_Target);
         begin
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success
               and then Info.Available
               and then Info.Kind = Hostkit.Fs.FIFO,
               "REG-CP-0003 cp recreates FIFO special files through hostkit");
         end;
      end if;

      if Hostkit.Fs.Create_Socket (Cp_Socket_Source, 8#600#) then
         Context.Initialize ("cp", Two_Args (Cp_Socket_Source, Cp_Socket_Target));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         declare
            Info : constant Hostkit.Fs.Special_File_Info := Hostkit.Fs.Special_File_Info_Of (Cp_Socket_Target);
         begin
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success
               and then Info.Available
               and then Info.Kind = Hostkit.Fs.Socket,
               "REG-CP-0004 cp recreates Unix-domain socket files through hostkit");
         end;
      end if;

      Ada.Directories.Create_Directory (Tree);
      Write_File (Tree & "/child.txt", "child");
      Write_File (Target, "ordinary-target");
      Context.Initialize ("cp", Three_Args ("-R", Tree, Target));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "not a directory"),
         "cp -R rejects existing non-directory destination");
      Remove_Any (Tree);

      Context.Initialize ("cp", Two_Args ("-fp", Source));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "cp grouped -fp still requires target");

      Context.Initialize ("cp", Two_Args ("-i", Source));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "cp accepts -i before validating operands");

      Write_File (Target, "existing-data");
      Context.Initialize ("cp", Three_Args ("-i", Source, Target));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Error_Output (Context) = "cp: overwrite '" & Target & "'?" & EOL,
         "cp -i declines overwrite status and prompt");
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "existing-data", "cp -i decline preserves target");

      Context.Initialize ("cp", Three_Args ("-i", Source, Target));
      Test_Contexts.Set_Standard_Input (Context, "y" & EOL);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp -i confirms status");
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "copy-data", "cp -i confirm overwrites target");

      Write_File (Target, "existing-data");
      Context.Initialize ("cp", Three_Args ("-if", Source, Target));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Error_Output (Context) = "",
         "cp -if uses final force option");
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "copy-data", "cp -if overwrites target");

      Write_File (Target, "existing-data");
      Context.Initialize ("cp", Three_Args ("-fi", Source, Target));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp -fi uses final interactive option");
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "existing-data", "cp -fi preserves target");

      Context.Initialize ("cp", Three_Args ("-i", Source, Target));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Error_Output (Context) = "cp: overskriv '" & Target & "'?" & EOL,
         "REG-CP-0002 cp localizes interactive overwrite prompt");

      Ada.Directories.Create_Path (Tree & "/sub");
      Write_File (Tree & "/sub/file.txt", "tree-data");
      Context.Initialize ("cp", Three_Args ("-R", Tree, Tree_Copy));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp -R status");
      Context.Initialize ("cat", One_Arg (Tree_Copy & "/sub/file.txt"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "tree-data", "cp -R copied nested data");

      Context.Initialize ("cp", Three_Args ("-R", Tree, Tree & "/inside"));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "same file")
         and then not Ada.Directories.Exists (Tree & "/inside"),
         "cp -R rejects copying directory into itself");

      Remove_Any (Tree_Copy);
      Context.Initialize ("cp", Three_Args ("-Rp", Tree, Tree_Copy));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp -Rp status");

      Context.Initialize ("ln", Two_Args (Source, Linked));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "ln status");
      AUnit.Assertions.Assert (Hostkit.Metadata.Same_File (Source, Linked), "ln creates hard link");

      Remove_Any (Linked);
      Context.Initialize ("ln", Three_Args ("--", Source, Linked));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "ln -- status");
      AUnit.Assertions.Assert (Hostkit.Metadata.Same_File (Source, Linked), "ln -- creates hard link");

      Write_File (Linked, "old-link-target");
      Write_File (Source, "copy-data");
      Context.Initialize ("ln", Three_Args ("-f", Source, Linked));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "ln -f status");
      Context.Initialize ("cat", One_Arg (Linked));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "copy-data", "ln -f replaced target data");
      AUnit.Assertions.Assert (Hostkit.Metadata.Same_File (Source, Linked), "ln -f creates hard link");

      Remove_Any (Linked);
      Context.Initialize ("ln", Three_Args ("-v", Source, Linked));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Hostkit.Metadata.Same_File (Source, Linked)
         and then Test_Contexts.Output (Context) = "'" & Source & "' -> '" & Linked & "'" & EOL,
         "ln verbose output");

      Remove_Any (Linked);
      Context.Initialize ("ln", Three_Args ("-v", Source, Linked));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "ln verbose output failure status");
      Remove_Any (Linked);
      Write_File (Linked, "move-data");

      Context.Initialize ("ln", Three_Args ("-s", Source, Symlinked));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      if Result.Status = Posix_Tools.Exit_Status.Success then
         declare
            Target_Text : Unbounded_String;
         begin
            AUnit.Assertions.Assert (Hostkit.Fs.Is_Link (Symlinked), "ln -s creates symbolic link");
            AUnit.Assertions.Assert
              (Hostkit.Fs.Read_Link_Target (Symlinked, Target_Text)
               and then To_String (Target_Text) = Source,
               "ln -s records requested target");
         end;
      else
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "ln -s reports host refusal as operational failure");
      end if;

      Ada.Directories.Create_Directory (Link_Dir);
      Write_File (Other, "other-data");
      Context.Initialize ("ln", Three_Args (Source, Other, Link_Dir));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "ln directory target status");
      AUnit.Assertions.Assert
        (Hostkit.Metadata.Same_File (Source, Hostkit.Fs.Join (Link_Dir, "command-source.txt"))
         and then Hostkit.Metadata.Same_File (Other, Hostkit.Fs.Join (Link_Dir, "command-other.txt")),
         "ln creates links inside directory target");

      Context.Initialize ("link", Two_Args (Source, Link_Command_Target));
      Posix_Tools.Commands.Link.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Hostkit.Metadata.Same_File (Source, Link_Command_Target),
         "link creates hard link");

      if Hostkit.Fs.Is_Link (Symlinked) then
         Context.Initialize ("readlink", One_Arg (Symlinked));
         Posix_Tools.Commands.Readlink.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = Source & EOL,
            "readlink writes symbolic link target");
      end if;

      Context.Initialize ("realpath", One_Arg (Source));
      Posix_Tools.Commands.Realpath.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Hostkit.Fs.Real_Path (Source) & EOL,
         "realpath writes resolved path");

      Write_File (Chmod_Target, "mode-data");
      Context.Initialize ("chmod", Two_Args ("600", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chmod status");
      Assert_Mode_When_Available (Chmod_Target, 8#600#, "chmod applies octal mode");

      Context.Initialize ("chmod", Two_Args ("u=rw,go=", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chmod symbolic assignment status");
      Assert_Mode_When_Available (Chmod_Target, 8#600#, "chmod applies symbolic assignment mode");

      Context.Initialize ("chmod", Two_Args ("g+r,o+r", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chmod symbolic add status");
      Assert_Mode_When_Available (Chmod_Target, 8#644#, "chmod applies symbolic add mode");

      Context.Initialize ("chmod", Two_Args ("-w", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chmod symbolic hyphen-start status");
      Assert_Mode_When_Available (Chmod_Target, 8#444#, "chmod treats -w as a symbolic mode");

      Context.Initialize ("chmod", Two_Args ("u+x,g=u,o=g", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chmod symbolic copy status");
      Assert_Mode_When_Available (Chmod_Target, 8#555#, "chmod applies symbolic copy mode");

      Context.Initialize ("chmod", Two_Args ("u+", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "chmod rejects incomplete symbolic mode");

      declare
         User      : Natural;
         Group     : Natural;
         Available : Boolean;
      begin
         Hostkit.Metadata.File_Ownership (Chmod_Target, User, Group, Available);
         if Available then
            Context.Initialize ("chown", Two_Args (Trim_Natural (User), Chmod_Target));
            Posix_Tools.Commands.Chown.Run (Context, Result);
            AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chown current user status");
            Context.Initialize ("chgrp", Two_Args (Trim_Natural (Group), Chmod_Target));
            Posix_Tools.Commands.Chgrp.Run (Context, Result);
            AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chgrp current group status");
         end if;
      end;

      Context.Initialize ("uname", No_Args);
      Posix_Tools.Commands.Uname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context)'Length > 1,
         "uname writes system name");

      Context.Initialize ("uname", One_Arg ("-a"));
      Posix_Tools.Commands.Uname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), " ")
         and then not Contains (Test_Contexts.Output (Context), "unknown"),
         "uname -a writes multiple system fields");

      Context.Initialize ("sleep", One_Arg ("0"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "sleep zero status");

      Context.Initialize ("sleep", One_Arg ("0s"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "sleep seconds suffix status");

      Context.Initialize ("sleep", One_Arg ("0m"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "sleep minutes suffix status");

      Context.Initialize ("sleep", One_Arg ("0h"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "sleep hours suffix status");

      Context.Initialize ("sleep", One_Arg ("0d"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "sleep days suffix status");

      Context.Initialize ("sleep", Two_Args ("0.0", "0.00s"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "sleep accepts fractional zero durations");

      Context.Initialize ("sleep", No_Args);
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sleep rejects missing operands");

      Context.Initialize ("sleep", One_Arg ("-1"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sleep rejects negative durations");

      Context.Initialize ("sleep", Two_Args ("31622400", "1"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sleep rejects duration sums above the implementation limit");

      Context.Initialize ("sleep", One_Arg ("31622400d"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sleep rejects suffixed durations above the implementation limit");

      Context.Initialize ("sleep", One_Arg ("999999999999999999999999999999999999999"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sleep rejects overflowing duration");

      Context.Initialize ("sleep", One_Arg ("0x"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sleep rejects unknown suffix");

      Context.Initialize ("id", One_Arg ("-u"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context)'Length > 1,
         "id -u writes identity");

      Context.Initialize ("id", One_Arg ("-G"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context)'Length > 1,
         "id -G writes group list");

      Context.Initialize ("whoami", No_Args);
      Posix_Tools.Commands.Whoami.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context)'Length > 1,
         "whoami writes name");

      Context.Initialize ("logname", No_Args);
      Test_Contexts.Set_Environment_Value (Context, "LOGNAME", "test-login");
      Posix_Tools.Commands.Logname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-login" & EOL,
         "logname writes context login name");

      Context.Initialize ("logname", No_Args);
      Posix_Tools.Commands.Logname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context)'Length > 1,
         "logname falls back to host login database");

      Context.Initialize ("kill", One_Arg ("-l"));
      Posix_Tools.Commands.Kill.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context)'Length > 0,
         "kill -l lists signals");

      Context.Initialize ("mv", Three_Args ("-ff", Linked, Moved));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "mv grouped -f status");

      Write_File (Linked, "move-data");
      Write_File (Moved, "existing-data");
      Context.Initialize ("mv", Three_Args ("-i", Linked, Moved));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Linked)
         and then Ada.Directories.Exists (Moved)
         and then Test_Contexts.Error_Output (Context) = "mv: overwrite '" & Moved & "'?" & EOL,
         "mv -i declines overwrite");

      Context.Initialize ("mv", Three_Args ("-i", Linked, Moved));
      Test_Contexts.Set_Standard_Input (Context, "y" & EOL);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Linked)
         and then Ada.Directories.Exists (Moved),
         "mv -i confirms overwrite");

      Write_File (Linked, "move-data");
      Write_File (Moved, "existing-data");
      Context.Initialize ("mv", Three_Args ("-if", Linked, Moved));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Linked)
         and then Test_Contexts.Error_Output (Context) = "",
         "mv -if uses final force option");

      Write_File (Linked, "move-data");
      Write_File (Moved, "existing-data");
      Context.Initialize ("mv", Three_Args ("-fi", Linked, Moved));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Linked)
         and then Ada.Directories.Exists (Moved),
         "mv -fi uses final interactive option");
      Remove_Any (Linked);
      Remove_Any (Moved);

      Write_File (Moved, "move-data");
      Context.Initialize ("rm", One_Arg (Moved));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "rm status");

      Write_File (Rm_Interactive, "interactive-data");
      Context.Initialize ("rm", Two_Args ("-i", Rm_Interactive));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Rm_Interactive)
         and then Test_Contexts.Error_Output (Context) = "rm: remove '" & Rm_Interactive & "'?" & EOL,
         "rm -i declines removal");

      Context.Initialize ("rm", Two_Args ("-i", Rm_Interactive));
      Test_Contexts.Set_Standard_Input (Context, "y" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Rm_Interactive),
         "rm -i confirms removal");

      Write_File (Rm_Interactive, "interactive-data");
      Context.Initialize ("rm", Two_Args ("-if", Rm_Interactive));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Rm_Interactive),
         "rm -if uses final force option");

      Write_File (Rm_Interactive, "interactive-data");
      Context.Initialize ("rm", Two_Args ("-fi", Rm_Interactive));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Rm_Interactive),
         "rm -fi uses final interactive option");
      Remove_Any (Rm_Interactive);

      Write_File (Linked, "move-data");
      Context.Initialize ("mv", Four_Args ("-f", "--", Linked, Moved));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Moved),
         "mv accepts -- after -f");
      Remove_Any (Moved);

      Context.Initialize ("mv", One_Arg ("-z"));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "mv rejects unknown grouped option");

      Context.Initialize ("mv", One_Arg ("-i"));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "mv accepts -i before validating operands");

      Ada.Directories.Create_Directory (Remove_Dir);
      Context.Initialize ("rm", Two_Args ("-d", Remove_Dir));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Remove_Dir),
         "rm -d removed empty directory");

      Context.Initialize ("mkdir", Four_Args ("-m", "755", "-p", Made));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert (Ada.Directories.Exists (Made), "mkdir created directory");
      Assert_Mode_When_Available (Made, 8#755#, "mkdir applied separate mode");

      Remove_Any (Made);
      Context.Initialize ("mkdir", Two_Args ("-pm755", Made));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Made),
         "mkdir accepts grouped -pm mode");
      Assert_Mode_When_Available (Made, 8#755#, "mkdir applied grouped mode");

      Context.Initialize ("mkdir", Three_Args ("-m", "u=rwx,go=rx", Symbolic_Mode_Dir));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Symbolic_Mode_Dir),
         "mkdir accepts symbolic assignment mode");
      Assert_Mode_When_Available (Symbolic_Mode_Dir, 8#755#, "mkdir applied symbolic assignment mode");

      Context.Initialize ("mkdir", Three_Args ("-m", "a=,u+rwx,go+rx", Relative_Mode_Dir));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Relative_Mode_Dir),
         "mkdir accepts symbolic relative mode clauses");
      Assert_Mode_When_Available (Relative_Mode_Dir, 8#755#, "mkdir applied symbolic relative mode");

      Remove_Any (Relative_Mode_Dir);
      Context.Initialize ("mkdir", Three_Args ("-m", "u=rwx,g=u,o=g", Relative_Mode_Dir));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Relative_Mode_Dir),
         "mkdir accepts symbolic copy mode clauses");
      Assert_Mode_When_Available (Relative_Mode_Dir, 8#777#, "mkdir applied symbolic copy mode");

      Remove_Any (Relative_Mode_Dir);
      Context.Initialize ("mkdir", Three_Args ("-m", "u=rwxs,g=rxs,o=rxt", Relative_Mode_Dir));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Relative_Mode_Dir),
         "mkdir accepts symbolic special bits");
      Assert_Full_Mode_When_Available (Relative_Mode_Dir, 8#7755#, "mkdir applied symbolic special bits");

      Remove_Any (Relative_Mode_Dir);
      Context.Initialize ("mkdir", Three_Args ("-m", "a=rwX", Relative_Mode_Dir));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Relative_Mode_Dir),
         "mkdir accepts symbolic conditional execute");
      Assert_Mode_When_Available (Relative_Mode_Dir, 8#777#, "mkdir applied symbolic conditional execute");

      Context.Initialize ("mkdir", Two_Args ("-m", "bad"));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "mkdir rejects invalid mode");

      Context.Initialize ("mkdir", One_Arg ("-pmbad"));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "mkdir rejects invalid attached mode");

      Context.Initialize ("mkdir", One_Arg ("-q"));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "mkdir rejects unknown option");

      Context.Initialize ("arch", No_Args);
      Posix_Tools.Commands.Arch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) /= "",
         "arch reports machine class");

      Context.Initialize ("df", No_Args);
      Posix_Tools.Commands.Df.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), "Filesystem 512-blocks Used Available"),
         "df reports current filesystem capacity");

      Context.Initialize ("getconf", One_Arg ("POSIX_VERSION"));
      Posix_Tools.Commands.Getconf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "202405" & EOL,
         "getconf POSIX_VERSION");

      Context.Initialize ("getconf", One_Arg ("NO_SUCH_VARIABLE"));
      Posix_Tools.Commands.Getconf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "getconf rejects unknown variable");

      Context.Initialize ("groups", No_Args);
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-primary test-extra" & EOL,
         "groups writes current group list");

      Context.Initialize ("groups", One_Arg ("named-user"));
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "named-user : named-extra test-primary" & EOL,
         "groups writes named user group list");

      Context.Initialize ("groups", One_Arg ("missing-user"));
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) /= "",
         "groups reports missing user group list");

      Context.Initialize ("locale", No_Args);
      Test_Contexts.Set_Environment_Value (Context, "LANG", "en_US.UTF-8");
      Posix_Tools.Commands.Locale.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), "LANG=""en_US.UTF-8"""),
         "locale reports effective LANG");

      Context.Initialize ("locale", One_Arg ("-a"));
      Posix_Tools.Commands.Locale.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "C" & EOL & "POSIX" & EOL,
         "locale -a portable list");

      Context.Initialize ("hostname", No_Args);
      Posix_Tools.Commands.Hostname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-node" & EOL,
         "hostname reports node name");

      Context.Initialize ("hostname", One_Arg ("new-node"));
      Test_Contexts.Set_Node_Name_Allowed (Context, True);
      Posix_Tools.Commands.Hostname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Node_Name_Set_Called (Context)
         and then Test_Contexts.Captured_Node_Name (Context) = "new-node",
         "hostname sets node name through context");

      Context.Initialize ("hostname", One_Arg ("denied-node"));
      Posix_Tools.Commands.Hostname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) /= "",
         "hostname reports failed node-name set");

      Context.Initialize ("mkfifo", Three_Args ("-m", "600", Mkfifo_Target));
      Posix_Tools.Commands.Mkfifo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status in Posix_Tools.Exit_Status.Success | Posix_Tools.Exit_Status.Operational_Failure,
         "mkfifo status reflects host support");
      if Result.Status = Posix_Tools.Exit_Status.Success then
         AUnit.Assertions.Assert (Ada.Directories.Exists (Mkfifo_Target), "mkfifo creates filesystem entry");
      else
         AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) /= "", "mkfifo unsupported diagnostic");
      end if;

      Context.Initialize ("nice", Two_Args ("-n5", "true"));
      Posix_Tools.Commands.Nice.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Nice_Adjustment (Context) = 5,
         "nice applies compact adjustment");

      Context.Initialize ("nice", Two_Args ("-n+", "true"));
      Posix_Tools.Commands.Nice.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "nice rejects sign-only adjustment");

      Context.Initialize ("nice", Three_Args ("-n", "2147483648", "true"));
      Posix_Tools.Commands.Nice.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "nice rejects overflowing adjustment");

      Context.Initialize ("nice", One_Arg ("false"));
      Posix_Tools.Commands.Nice.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Nice_Adjustment (Context) = 10,
         "nice applies default adjustment");

      Context.Initialize ("nohup", One_Arg ("true"));
      Posix_Tools.Commands.Nohup.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "nohup propagates true status");

      Context.Initialize ("nohup", One_Arg ("true"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, True);
      Posix_Tools.Commands.Nohup.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Redirected_Output_Path (Context) = "nohup.out"
         and then Test_Contexts.Redirected_Output_Enabled (Context)
         and then Test_Contexts.Redirected_Error_Enabled (Context),
         "nohup redirects terminal output to nohup.out");

      Context.Initialize ("printenv", One_Arg ("POSIX_TOOLS_TEST_PRINTENV"));
      Test_Contexts.Set_Environment_Value (Context, "POSIX_TOOLS_TEST_PRINTENV", "printed-value");
      Posix_Tools.Commands.Printenv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "printed-value" & EOL,
         "printenv selected variable");

      Context.Initialize ("printenv", One_Arg ("POSIX_TOOLS_TEST_MISSING"));
      Posix_Tools.Commands.Printenv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "printenv missing variable status");

      Context.Initialize ("which", One_Arg ("POSIX_TOOLS_NO_SUCH_COMMAND"));
      Posix_Tools.Commands.Which.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "which reports missing command through status");

      Context.Initialize ("stat", One_Arg (Source));
      Posix_Tools.Commands.Stat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), "File: " & Source & EOL)
         and then Contains (Test_Contexts.Output (Context), "Size: 9" & EOL)
         and then Contains (Test_Contexts.Output (Context), "Type: regular file" & EOL)
         and then Contains (Test_Contexts.Output (Context), "Mode: "),
         "stat reports regular file metadata");

      Context.Initialize ("stat", Three_Args ("-c", "%n %s %F", Source));
      Posix_Tools.Commands.Stat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Source & " 9 regular file" & EOL,
         "stat supports custom format fields");

      Context.Initialize ("stat", Three_Args ("-c", "%x|%X|%y|%Y|%w|%W", Source));
      Posix_Tools.Commands.Stat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Contains (Test_Contexts.Output (Context), "%x")
         and then not Contains (Test_Contexts.Output (Context), "%X")
         and then not Contains (Test_Contexts.Output (Context), "%y")
         and then not Contains (Test_Contexts.Output (Context), "%Y")
         and then not Contains (Test_Contexts.Output (Context), "%w")
         and then not Contains (Test_Contexts.Output (Context), "%W"),
         "stat supports timestamp format fields");

      Ada.Directories.Create_Directory (Multi);
      Write_File (Other, "other-data");
      Context.Initialize ("cp", Three_Args (Source, Other, Multi));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Multi & "/command-source.txt")
         and then Ada.Directories.Exists (Multi & "/command-other.txt"),
         "cp multiple sources into directory");

      Remove_Any (Target);
      Context.Initialize ("cp", Three_Args ("-v", Source, Target));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "'" & Source & "' -> '" & Target & "'" & EOL,
         "cp verbose output");

      Remove_Any (Target);
      Context.Initialize ("cp", Three_Args ("-v", Source, Target));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cp verbose output failure status");

      Context.Initialize
        ("mv",
         Three_Args
           (Multi & "/command-source.txt",
            Multi & "/command-other.txt",
            Made));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Made & "/command-source.txt")
         and then Ada.Directories.Exists (Made & "/command-other.txt"),
         "mv multiple sources into directory");

      Remove_Any (Option_Dir);
      Ada.Directories.Create_Directory (Option_Dir);
      Ada.Directories.Create_Directory (Hostkit.Fs.Join (Option_Dir, "moves"));
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "plain-data");
      Write_File (Hostkit.Fs.Join (Option_Dir, "-v"), "dash-data");
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);
         Context.Initialize ("mv", Three_Args ("plain", "-v", "moves"));
         Posix_Tools.Commands.Mv.Run (Context, Result);
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Hostkit.Fs.Join (Hostkit.Fs.Join (Option_Dir, "moves"), "plain"))
         and then Ada.Directories.Exists (Hostkit.Fs.Join (Hostkit.Fs.Join (Option_Dir, "moves"), "-v"))
         and then Test_Contexts.Output (Context) = "",
         "mv treats option-like words after first operand as operands");

      Write_File (Source, "move-verbose-data");
      Remove_Any (Target);
      Context.Initialize ("mv", Three_Args ("-v", Source, Target));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Target)
         and then Test_Contexts.Output (Context) = "'" & Source & "' -> '" & Target & "'" & EOL,
         "mv verbose output");

      Write_File (Source, "move-verbose-data");
      Remove_Any (Target);
      Context.Initialize ("mv", Three_Args ("-v", Source, Target));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "mv verbose output failure status");
      Write_File (Source, "copy-data");
      Remove_Any (Target);

      Ada.Directories.Create_Path (Empty & "/a/b");
      Context.Initialize ("rmdir", Two_Args ("-p", Empty & "/a/b"));
      Posix_Tools.Commands.Rmdir.Run (Context, Result);
      AUnit.Assertions.Assert (not Ada.Directories.Exists (Empty), "rmdir removed parent path");

      Ada.Directories.Create_Path (Remove_Dir & "/a/b");
      Context.Initialize ("rmdir", Three_Args ("-p", "--", Remove_Dir & "/a/b"));
      Posix_Tools.Commands.Rmdir.Run (Context, Result);
      AUnit.Assertions.Assert (not Ada.Directories.Exists (Remove_Dir), "rmdir accepts -- after -p");

      Ada.Directories.Create_Path (Parent_Block & "/a/b");
      Write_File (Parent_Block & "/keep.txt", "keep");
      Context.Initialize ("rmdir", Two_Args ("-p", Parent_Block & "/a/b"));
      Posix_Tools.Commands.Rmdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Ada.Directories.Exists (Parent_Block)
         and then not Ada.Directories.Exists (Parent_Block & "/a"),
         "rmdir -p reports blocked parent after removing empty components");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Test_Contexts.Error_Output (Context), Parent_Block) > 0,
         "rmdir -p diagnostic names blocked parent");

      Context.Initialize ("rmdir", One_Arg ("-z"));
      Posix_Tools.Commands.Rmdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "rmdir rejects unknown option");

      Write_File (Rm_Interactive, "remove-data");
      Context.Initialize ("rm", Two_Args ("-i", Rm_Interactive));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Rm_Interactive)
         and then Test_Contexts.Output (Context) = "",
         "rm -i without response declines removal");
      Remove_Any (Rm_Interactive);

      Write_File (Rm_Interactive, "remove-data");
      Context.Initialize ("rm", Two_Args ("-v", Rm_Interactive));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Rm_Interactive)
         and then Test_Contexts.Output (Context) = "removed '" & Rm_Interactive & "'" & EOL,
         "rm verbose output");

      Write_File (Rm_Interactive, "remove-data");
      Context.Initialize ("rm", Two_Args ("-v", Rm_Interactive));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then not Ada.Directories.Exists (Rm_Interactive),
         "rm verbose output failure status");

      Remove_Any (Option_Dir);
      Ada.Directories.Create_Directory (Option_Dir);
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);

         Context.Initialize ("mkdir", Two_Args ("plain", "-p"));
         Posix_Tools.Commands.Mkdir.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Ada.Directories.Exists ("plain")
            and then Ada.Directories.Exists ("-p"),
            "mkdir treats option-like words after first operand as operands");
         Ada.Directories.Delete_Directory ("plain");
         Ada.Directories.Delete_Directory ("-p");

         Write_File ("plain-link-source", "link-data");
         Write_File ("-s", "dash-link-data");
         Ada.Directories.Create_Directory ("links");
         Context.Initialize ("ln", Three_Args ("plain-link-source", "-s", "links"));
         Posix_Tools.Commands.Ln.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Ada.Directories.Exists (Hostkit.Fs.Join ("links", "plain-link-source"))
            and then Ada.Directories.Exists (Hostkit.Fs.Join ("links", "-s")),
            "ln treats option-like words after first operand as operands");

         Write_File ("plain-file", "remove-data");
         Write_File ("-f", "remove-data");
         Context.Initialize ("rm", Two_Args ("plain-file", "-f"));
         Posix_Tools.Commands.Rm.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then not Ada.Directories.Exists ("plain-file")
            and then not Ada.Directories.Exists ("-f"),
            "rm treats option-like words after first operand as operands");

         Ada.Directories.Create_Directory ("plain-dir");
         Ada.Directories.Create_Directory ("-p");
         Context.Initialize ("rmdir", Two_Args ("plain-dir", "-p"));
         Posix_Tools.Commands.Rmdir.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then not Ada.Directories.Exists ("plain-dir")
            and then not Ada.Directories.Exists ("-p"),
            "rmdir treats option-like words after first operand as operands");

         Context.Initialize ("touch", Two_Args ("plain-touch", "-c"));
         Posix_Tools.Commands.Touch.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Ada.Directories.Exists ("plain-touch")
            and then Ada.Directories.Exists ("-c"),
            "touch treats option-like words after first operand as operands");

         Context.Initialize ("tee", Two_Args ("plain-tee", "-a"));
         Test_Contexts.Set_Standard_Input (Context, "tee-boundary");
         Posix_Tools.Commands.Tee.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = "tee-boundary"
            and then Ada.Directories.Exists ("plain-tee")
            and then Ada.Directories.Exists ("-a"),
            "tee treats option-like words after first operand as operands");

         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;

      Context.Initialize ("touch", One_Arg (Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Ada.Directories.Exists (Touched), "touch created file");

      Write_File (Touched, "touch-data");
      Context.Initialize ("touch", One_Arg (Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "touch existing status");
      Context.Initialize ("cat", One_Arg (Touched));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "touch-data", "touch preserves existing data");

      Context.Initialize ("touch", Two_Args ("-c", No_Create));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (No_Create),
         "touch -c leaves missing file absent");

      Context.Initialize ("touch", Two_Args ("-am", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "touch -am status");

      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (Touched,
         GNAT.OS_Lib.GM_Time_Of
           (2026,
            8,
            12,
            10,
            0,
            0));
      Context.Initialize ("touch", Three_Args ("-a", "-t202608121540.11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (10 * 3_600))),
         "touch -a leaves modification timestamp unchanged");
      declare
         Expected_Access : constant Ada.Calendar.Time :=
           Ada.Calendar.Time_Of (1970, 1, 1) + 1_786_542_011.0;
         Available : Boolean;
         Accessed  : constant Ada.Calendar.Time := Hostkit.Metadata.File_Access_Time (Touched, Available);
      begin
         if Available then
            AUnit.Assertions.Assert
              (Time_Near (Accessed, Expected_Access),
               "touch -a applies explicit access timestamp");
         end if;
      end;

      Context.Initialize ("touch", Three_Args ("-m", "-t202608121540.11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 40 * 60 + 11))),
         "touch -m applies explicit modification timestamp");

      Context.Initialize ("touch", Three_Args ("-r", Source, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near (Ada.Directories.Modification_Time (Touched), Ada.Directories.Modification_Time (Source)),
         "touch -r status and timestamp");

      Context.Initialize ("touch", Two_Args ("-r" & Source, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near (Ada.Directories.Modification_Time (Touched), Ada.Directories.Modification_Time (Source)),
         "touch compact -r status and timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121530.45", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 30 * 60 + 45))),
         "touch -t status and timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121531", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 31 * 60))),
         "touch -t explicit century minute timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121531.46", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 31 * 60 + 46))),
         "touch -t explicit century seconds timestamp");

      Context.Initialize ("touch", Two_Args ("-t08121530", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of
              (Ada.Calendar.Year (Ada.Calendar.Clock), 8, 12, Duration (15 * 3_600 + 30 * 60))),
         "touch compact -t status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "202608121631.05", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 31 * 60 + 5))),
         "touch -d status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d202608121632.06", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 32 * 60 + 6))),
         "touch compact -d status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:33:07", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 33 * 60 + 7))),
         "touch -d ISO date-time status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-12 16:34:08", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 34 * 60 + 8))),
         "touch compact -d spaced date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:35:09Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 35 * 60 + 9))),
         "touch -d UTC date-time status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-12 16:36:10Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 36 * 60 + 10))),
         "touch compact -d UTC spaced date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:35:09+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (14 * 3_600 + 5 * 60 + 9))),
         "touch -d positive numeric offset status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12 16:36:10-0330", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (20 * 3_600 + 6 * 60 + 10))),
         "touch -d negative numeric offset status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, 0.0)),
         "touch -d date-only status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-13T17:45", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 45 * 60))),
         "touch compact -d minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:46Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 46 * 60))),
         "touch -d UTC minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:47+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (15 * 3_600 + 17 * 60))),
         "touch -d positive offset minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026/08/13 17:48:11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 48 * 60 + 11))),
         "touch -d slash date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13t17:49:12Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 49 * 60 + 12))),
         "touch -d lowercase-t UTC date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:50:13.987+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (15 * 3_600 + 20 * 60 + 13))),
         "touch -d fractional offset date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Aug 13 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 51 * 60 + 14))),
         "touch -d abbreviated month-name date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "August 13, 2026 17:52", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 52 * 60))),
         "touch -d full month-name minute timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Sep 14 2026", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 9, 14, 0.0)),
         "touch -d month-name date-only timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "13 Aug 2026 17:53:16", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 53 * 60 + 16))),
         "touch -d day-first abbreviated month-name timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "14 September 2026", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 9, 14, 0.0)),
         "touch -d day-first full month-name date-only timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "noon", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      declare
         Year : Ada.Calendar.Year_Number;
         Month : Ada.Calendar.Month_Number;
         Day : Ada.Calendar.Day_Number;
         Seconds : Duration;
      begin
         Ada.Calendar.Split (Ada.Calendar.Clock, Year, Month, Day, Seconds);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near
              (Ada.Directories.Modification_Time (Touched),
               Ada.Calendar.Time_Of (Year, Month, Day, Duration (12 * 3_600))),
            "touch -d noon timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "2 hours ago", Touched));
      declare
         Expected : constant Ada.Calendar.Time := Ada.Calendar.Clock - Duration (2 * 3_600);
      begin
         Posix_Tools.Commands.Touch.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near (Ada.Directories.Modification_Time (Touched), Expected),
            "touch -d relative hours ago timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "+1 day", Touched));
      declare
         Expected : constant Ada.Calendar.Time := Ada.Calendar.Clock + 86_400.0;
      begin
         Posix_Tools.Commands.Touch.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near (Ada.Directories.Modification_Time (Touched), Expected),
            "touch -d relative plus day timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "bad", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid -d timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Nope 13 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid month-name -d timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "32 Aug 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid day-first month-name -d timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202613121530", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid timestamp");

      Context.Initialize ("touch", Three_Args ("-r", No_Create, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "touch missing reference status");

      Context.Initialize ("touch", Two_Args ("-ac", No_Create));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (No_Create),
         "touch grouped -ac leaves missing file absent");

      Context.Initialize ("dd", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "abcdef"
         and then Test_Contexts.Error_Output (Context) = "0+1 records in" & EOL & "0+1 records out" & EOL,
         "dd default block size records");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=3"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "abc"
         and then Test_Contexts.Error_Output (Context) = "3+0 records in" & EOL & "3+0 records out" & EOL,
         "dd count output and records");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=0"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "0+0 records in" & EOL & "0+0 records out" & EOL,
         "dd count zero copies no records");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Error_Output (Context) = "",
         "dd reports standard-output failure");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=1b"));
      Test_Contexts.Set_Standard_Input (Context, String'(1 .. 520 => 'x'));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context)'Length = 512, "dd count b suffix output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=1K"));
      Test_Contexts.Set_Standard_Input (Context, String'(1 .. 1_030 => 'x'));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context)'Length = 1_024, "dd count K suffix output");

      Context.Initialize ("dd", Two_Args ("count=1", "bs=1M"));
      Test_Contexts.Set_Standard_Input (Context, "x");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "x", "dd M suffix block size output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=3w"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd count w suffix output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=3c"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "dd count c suffix output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=2x3"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd count x multiplier output");

      Context.Initialize ("dd", Three_Args ("bs=1", "count=2", "count=4"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcd", "dd later count operand wins");

      Context.Initialize ("dd", Two_Args ("bs=2", "count=2"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcd", "dd block count output");

      Context.Initialize ("dd", Two_Args ("bs=2x3", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd block x multiplier output");

      Context.Initialize ("dd", Three_Args ("files=1", "bs=1", "count=3"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "dd files operand output");

      Context.Initialize ("dd", One_Arg ("files=0"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects zero files operand");

      Context.Initialize ("dd", Two_Args ("ibs=3", "count=2"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd ibs count output");

      Context.Initialize ("dd", Three_Args ("bs=2", "skip=1", "count=2"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "cdef", "dd skip output");

      Context.Initialize ("dd", Three_Args ("ibs=3", "skip=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "dd ibs skip output");

      Context.Initialize ("dd", Three_Args ("ibs=3", "iseek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "dd iseek alias output");

      Context.Initialize ("dd", Three_Args ("bs=2", "seek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (0) & Character'Val (0) & "ab",
         "dd seek output");

      Context.Initialize ("dd", Four_Args ("ibs=1", "obs=3", "seek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (0) & Character'Val (0) & Character'Val (0) & "a",
         "dd obs seek output");

      Context.Initialize ("dd", Four_Args ("ibs=1", "obs=3", "oseek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (0) & Character'Val (0) & Character'Val (0) & "a",
         "dd oseek alias output");

      Context.Initialize ("dd", One_Arg ("conv=ucase"));
      Test_Contexts.Set_Standard_Input (Context, "aBz 12");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ABZ 12", "dd conv=ucase output");

      Context.Initialize ("dd", One_Arg ("conv=ucase,lcase"));
      Test_Contexts.Set_Standard_Input (Context, "aBz 12");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abz 12", "dd later conversion wins output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=ebcdic"));
      Test_Contexts.Set_Standard_Input (Context, "Az09");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (193) & Character'Val (169) & Character'Val (240) & Character'Val (249),
         "dd conv=ebcdic byte table output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=ascii"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (193) & Character'Val (169) & Character'Val (240) & Character'Val (249));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "Az09" & EOL, "dd conv=ascii byte table output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=ibm"));
      Test_Contexts.Set_Standard_Input (Context, "AZ");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (193) & Character'Val (233) & Character'Val (64) & Character'Val (64),
         "dd conv=ibm byte table output");

      Context.Initialize ("dd", One_Arg ("conv=ascii"));
      Test_Contexts.Set_Standard_Input (Context, "abcd");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd conv=ascii requires cbs");

      Context.Initialize ("dd", One_Arg ("conv=swab"));
      Test_Contexts.Set_Standard_Input (Context, "abcde");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "badce", "dd conv=swab odd output");

      Context.Initialize ("dd", One_Arg ("conv=noerror"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "abc",
         "dd conv=noerror normal input output");

      Context.Initialize ("dd", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "dd input failure without noerror status");

      Context.Initialize ("dd", One_Arg ("conv=noerror"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab",
         "dd conv=noerror retains readable prefix");

      Context.Initialize ("dd", Two_Args ("ibs=4", "conv=noerror"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab"
         and then Contains (Test_Contexts.Error_Output (Context), "cannot read file")
         and then Contains (Test_Contexts.Error_Output (Context), "0+1 records in"),
         "dd conv=noerror omits failed unsynchronized block tail");

      Context.Initialize ("dd", Two_Args ("ibs=4", "conv=noerror,sync"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab" & Character'Val (0) & Character'Val (0)
         and then Contains (Test_Contexts.Error_Output (Context), "cannot read file")
         and then Contains (Test_Contexts.Error_Output (Context), "0+1 records in")
         and then Contains (Test_Contexts.Error_Output (Context), "0+1 records out"),
         "dd conv=noerror sync pads failed input block");

      Context.Initialize ("dd", Two_Args ("ibs=4", "conv=sync"));
      Test_Contexts.Set_Standard_Input (Context, "ab");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "ab" & Character'Val (0) & Character'Val (0),
         "dd conv=sync pads short block");

      Context.Initialize ("dd", Three_Args ("ibs=4", "count=1", "conv=sync,swab"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "ba" & Character'Val (0) & "c",
         "dd conv=sync swab output");

      Context.Initialize ("dd", Three_Args ("bs=1", "conv=swab,ucase", "count=4"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "BADC", "dd conv=swab ucase output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=block"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "bcdef" & EOL & "xy");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a   " & "bcde" & "xy  ", "dd conv=block output");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "1 truncated record"),
         "dd conv=block reports singular truncated record");

      Context.Initialize ("dd", Two_Args ("cbs=2", "conv=block"));
      Test_Contexts.Set_Standard_Input (Context, "abc" & EOL & "def" & EOL);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "ab" & "de"
         and then Contains (Test_Contexts.Error_Output (Context), "2 truncated records"),
         "dd conv=block reports plural truncated records");

      Context.Initialize ("dd", Three_Args ("ibs=4", "cbs=4", "conv=sync,block"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a   ",
         "dd conv=sync block pads with spaces");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=unblock"));
      Test_Contexts.Set_Standard_Input (Context, "a   bcde");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "bcde" & EOL, "dd conv=unblock output");

      Context.Initialize ("dd", Three_Args ("ibs=4", "cbs=4", "conv=sync,unblock"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL,
         "dd conv=sync unblock pads with spaces");

      Context.Initialize ("dd", One_Arg ("conv=block"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd conv=block requires cbs");

      Write_File (Target, "abcdef");
      Context.Initialize ("dd", Four_Args ("of=" & Target, "bs=1", "count=2", "conv=notrunc"));
      Test_Contexts.Set_Standard_Input (Context, "XY");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "XYcdef", "dd conv=notrunc preserves tail");

      Write_File (Target, "abcdef");
      Context.Initialize ("dd", Five_Args ("of=" & Target, "bs=2", "seek=1", "count=1", "conv=notrunc"));
      Test_Contexts.Set_Standard_Input (Context, "XY");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abXYef", "dd conv=notrunc honors seek offset");

      Context.Initialize ("dd", Four_Args ("of=" & Target, "obs=1M", "seek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "Z");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Size (Target) = Ada.Directories.File_Size (1_048_577),
         "dd output file seek uses file offset");

      Context.Initialize ("dd", One_Arg ("bs=1q"));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects unsupported numeric suffix");

      Context.Initialize ("dd", One_Arg ("bs=999999999999999999999999999999G"));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects overflow numeric suffix");

      Context.Initialize ("dd", One_Arg ("bs=2x"));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects empty multiplier factor");

      Context.Initialize ("printf", Two_Args ("%s\n", "value"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "value" & EOL, "printf output");

      Context.Initialize ("printf", Three_Args ("%s\n", "one", "two"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "one" & EOL & "two" & EOL,
         "printf format reuse output");

      Context.Initialize ("printf", Two_Args ("%d\n", "42"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "42" & EOL, "printf decimal output");

      Context.Initialize ("printf", Three_Args ("%d\n", "+0007", "-0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7" & EOL & "0" & EOL,
         "printf canonical decimal output");

      Context.Initialize ("printf", Three_Args ("%i\n", "+0007", "-0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7" & EOL & "0" & EOL,
         "printf signed integer output");

      Context.Initialize ("printf", Three_Args ("%u\n", "+0007", "0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7" & EOL & "0" & EOL,
         "printf unsigned decimal output");

      Context.Initialize ("printf", Four_Args ("%o:%x:%X", "15", "255", "255"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "17:ff:FF",
         "printf unsigned base output");

      Context.Initialize ("printf", Two_Args ("%b", "a\nb"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b", "printf percent b newline");

      Context.Initialize ("printf", Two_Args ("%b", "\101\102"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "AB", "printf percent b octal");

      Context.Initialize ("printf", Three_Args ("%5s:%3d\n", "x", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "    x:  7" & EOL,
         "printf minimum width output");

      Context.Initialize ("printf", Three_Args ("%-5s:%-3d\n", "x", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "x    :7  " & EOL,
         "printf left-justified width output");

      Context.Initialize ("printf", Two_Args ("%.3s", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "printf string precision output");

      Context.Initialize ("printf", Two_Args ("%5.3s", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  abc", "printf width precision output");

      Context.Initialize ("printf", Two_Args ("%-5.3s", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc  ", "printf left width precision output");

      Context.Initialize ("printf", Three_Args ("%*s", "5", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "    x", "printf star width output");

      Context.Initialize ("printf", Three_Args ("%*s", "-5", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "x    ", "printf negative star width output");

      Context.Initialize ("printf", Three_Args ("%.*s", "3", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "printf star precision output");

      Context.Initialize ("printf", Four_Args ("%*.*d", "6", "4", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  0007", "printf star width precision output");

      Context.Initialize ("printf", Three_Args ("%.4d:%.4d", "7", "-7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0007:-0007",
         "printf decimal precision output");

      Context.Initialize ("printf", Three_Args ("%6.4d:%-6.4d", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  0007:0007  ",
         "printf decimal width precision output");

      Context.Initialize ("printf", Three_Args ("%6.4u:%-6.4u", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  0007:0007  ",
         "printf unsigned width precision output");

      Context.Initialize ("printf", Three_Args ("%6.4x:%-6.4o", "255", "9"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  00ff:0011  ",
         "printf base width precision output");

      Context.Initialize ("printf", Four_Args ("%#o:%#x:%#X", "9", "255", "255"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "011:0xff:0XFF",
         "printf alternate base output");

      Context.Initialize ("printf", Four_Args ("%#o:%#x:%#X", "0", "0", "0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0:0:0",
         "printf alternate zero output");

      Context.Initialize ("printf", Two_Args ("%#08x", "255"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0x0000ff",
         "printf alternate zero-padded hex output");

      Context.Initialize ("printf", Four_Args ("%+d:% d:%+ d", "7", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+7: 7:+7",
         "printf signed flag output");

      Context.Initialize ("printf", Three_Args ("%f:%.2f", "1.5", "-2.345"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.500000:-2.35",
         "printf fixed floating output");

      Context.Initialize ("printf", Three_Args ("%8.2f:%-8.1f", "1.5", "2"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "    1.50:2.0     ",
         "printf fixed floating width output");

      Context.Initialize ("printf", Three_Args ("%+07.2f:% 5.1f", "1.5", "2"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+001.50:  2.0",
         "printf fixed floating flags output");

      Context.Initialize ("printf", Three_Args ("%e:%.2E", "1.5", "-0.01234"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.500000e+00:-1.23E-02",
         "printf scientific floating output");

      Context.Initialize ("printf", Two_Args ("%.2e", "1.2e3"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.20e+03",
         "printf scientific exponent input output");

      Context.Initialize ("printf", Two_Args ("%+010.2e", "12.34"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+01.23e+01",
         "printf scientific floating flags output");

      Context.Initialize ("printf", Four_Args ("%g:%g:%G", "1234", "0.0000123", "0.0000123"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1234:1.23e-05:1.23E-05",
         "printf general floating output");

      Context.Initialize ("printf", Three_Args ("%#.4g:%8.3g", "12.3", "12.3"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "12.30:    12.3",
         "printf general floating flags output");

      Context.Initialize ("printf", Three_Args ("%+i:%.4i", "7", "-7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+7:-0007",
         "printf signed integer flag precision output");

      Context.Initialize ("printf", Three_Args ("%f:%.2e", "1.5", "-12.3"));
      Test_Contexts.Set_Environment_Value (Context, "LC_NUMERIC", "da");
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1,500000:-1,23e+01",
         "printf uses LC_NUMERIC decimal separator");

      Context.Initialize ("printf", Three_Args ("%f:%.2e", "1.5", "-12.3"));
      Test_Contexts.Set_Environment_Value (Context, "LC_NUMERIC", "da");
      Test_Contexts.Set_Environment_Value (Context, "LC_ALL", "en");
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.500000:-1.23e+01",
         "printf LC_ALL overrides LC_NUMERIC");

      Context.Initialize ("printf", Four_Args ("%05d:%05d:%05u", "7", "-7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "00007:-0007:00007",
         "printf zero padding output");

      Context.Initialize ("printf", Three_Args ("%-05d:%05.3d", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7    :  007",
         "printf flag precedence output");

      Context.Initialize ("printf", Two_Args ("%5.3b", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  abc", "printf percent b width precision");

      Context.Initialize ("printf", Three_Args ("%b%s", "a\cignored", "later"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a", "printf percent b c stops output");

      Context.Initialize ("printf", Two_Args ("%.0d", "0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "printf zero decimal precision output");

      Context.Initialize ("printf", One_Arg ("%d:%u:%x:%f:%.1g"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0:0:0:0.000000:0",
         "printf missing numeric operands default to zero");

      Context.Initialize ("printf", Two_Args ("%*d:%.*s", "3"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  0:",
         "printf missing star and numeric operands default deterministically");

      Context.Initialize ("printf", Two_Args ("%s", "blocked"));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "printf reports standard-output failure");

      Context.Initialize ("printf", Two_Args ("%u", "-1"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid unsigned status");

      Context.Initialize ("printf", Three_Args ("%*s", "bad", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid star width status");

      Context.Initialize ("printf", Three_Args ("%*s", "9223372036854775808", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf overflowing star width status");

      Context.Initialize ("printf", Two_Args ("%999999999999999999999999999999999999999s", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf overflowing literal width status");

      Context.Initialize ("printf", Two_Args ("%.999999999999999999999999999999999999999s", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf overflowing literal precision status");

      Context.Initialize ("printf", Two_Args ("%x", "-1"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid hex status");

      Context.Initialize ("printf", Two_Args ("%d", "abc"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid decimal status");

      Context.Initialize ("printf", Two_Args ("%f", "abc"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid float status");

      Context.Initialize ("printf", Two_Args ("%f", "999999999999999999999999999999999999999.0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf fixed rejects overflowing whole part");

      Context.Initialize ("printf", Two_Args ("%.20f", "0.99999999999999999999"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf fixed rejects overflowing fraction part");

      Context.Initialize ("printf", Two_Args ("%e", "1e999999999999999999999999999999999999999"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf scientific rejects overflowing exponent");

      Context.Initialize ("printf", Two_Args ("%g", "1e999999999999999999999999999999999999999"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf general rejects overflowing exponent");

      Context.Initialize ("printf", Two_Args ("%i", "abc"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid signed integer status");

      Context.Initialize ("printf", Three_Args ("%c", "alpha", "beta"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "printf character reuse output");

      Context.Initialize ("printf", Three_Args ("%3c:%-3c", "alpha", "beta"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  a:b  ", "printf character width output");

      Context.Initialize ("printf", One_Arg ("%3c"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "   ", "printf missing character width output");

      Context.Initialize ("printf", One_Arg ("%%\t\\"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "%" & Character'Val (9) & "\",
         "printf escapes");

      Context.Initialize ("printf", One_Arg ("\a\b\f\v"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "" & Character'Val (7) & Character'Val (8) & Character'Val (12) & Character'Val (11),
         "printf control escapes");

      Context.Initialize ("printf", One_Arg ("\0101\0102"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "AB",
         "printf octal escapes");

      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL, "sort output");

      Context.Initialize ("sort", Two_Args ("-ru", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & EOL & "a" & EOL, "sort -ru output");

      Context.Initialize ("sort", Two_Args ("-f", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "A" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "A" & EOL & "b" & EOL, "sort -f output");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#85#) & EOL
         & Character'Val (16#C3#) & Character'Val (16#A5#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#C3#) & Character'Val (16#85#) & EOL,
         "sort -f folds UTF-8 Latin-1 case pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#CE#) & Character'Val (16#91#) & EOL
         & Character'Val (16#CE#) & Character'Val (16#B1#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#CE#) & Character'Val (16#91#) & EOL,
         "sort -f folds UTF-8 Greek case pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#D0#) & Character'Val (16#AF#) & EOL
         & Character'Val (16#D1#) & Character'Val (16#8F#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#D0#) & Character'Val (16#AF#) & EOL,
         "sort -f folds UTF-8 Cyrillic case pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C4#) & Character'Val (16#80#) & EOL
         & Character'Val (16#C4#) & Character'Val (16#81#) & EOL
         & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
         & Character'Val (16#D5#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#83#) & Character'Val (16#90#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C4#) & Character'Val (16#80#) & EOL
           & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
           & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL,
         "sort -f folds UTF-8 Latin Extended Armenian and Georgian pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C6#) & Character'Val (16#81#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#93#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#94#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#90#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#9B#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C6#) & Character'Val (16#81#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#90#) & EOL,
         "sort -f folds UTF-8 Latin Extended-B pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL
         & Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#A8#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL,
         "sort -f folds UTF-8 Deseret pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
         & Character'Val (16#EA#) & Character'Val (16#AD#) & Character'Val (16#B0#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BD#) & Character'Val (16#81#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
           & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL,
         "sort -f folds UTF-8 Cherokee and Fullwidth Latin pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#9F#) & EOL
         & "ss" & EOL
         & Character'Val (16#EF#) & Character'Val (16#AC#) & Character'Val (16#83#) & EOL
         & "ffi" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#EF#) & Character'Val (16#AC#) & Character'Val (16#83#) & EOL
           & Character'Val (16#C3#) & Character'Val (16#9F#) & EOL,
         "sort -f folds Unicode multi-code-point case mappings");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#E2#) & Character'Val (16#84#) & Character'Val (16#AA#) & EOL
         & "k" & EOL
         & Character'Val (16#CF#) & Character'Val (16#82#) & EOL
         & Character'Val (16#CF#) & Character'Val (16#83#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#E2#) & Character'Val (16#84#) & Character'Val (16#AA#) & EOL
           & Character'Val (16#CF#) & Character'Val (16#82#) & EOL,
         "sort -f folds Unicode compatibility and final-sigma mappings");

      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A5#) & EOL
         & "z" & EOL
         & Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
         & Character'Val (16#C3#) & Character'Val (16#B8#) & EOL
         & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "a" & EOL
           & "z" & EOL
           & Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
           & Character'Val (16#C3#) & Character'Val (16#B8#) & EOL
           & Character'Val (16#C3#) & Character'Val (16#A5#) & EOL,
         "sort uses Danish locale collation order");

      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "d" & EOL & "ch" & EOL & "c" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "c" & EOL & "ch" & EOL & "d" & EOL,
         "sort uses Spanish multibyte collation symbols");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         "z" & EOL
         & Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
         & Character'Val (16#C3#) & Character'Val (16#B8#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "sort -c uses Danish locale collation order");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
         & "z" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -c rejects Danish locale unordered input");

      Context.Initialize ("sort", Two_Args ("-b", "-"));
      Test_Contexts.Set_Standard_Input (Context, "  b" & EOL & " a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = " a" & EOL & "  b" & EOL, "sort -b output");

      Context.Initialize ("sort", Two_Args ("-bf", "-"));
      Test_Contexts.Set_Standard_Input (Context, "  beta" & EOL & " Alpha" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = " Alpha" & EOL & "  beta" & EOL,
         "sort grouped -bf output");

      Context.Initialize ("sort", Two_Args ("-d", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a#2" & EOL & "a 10" & EOL & "a!1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 10" & EOL & "a!1" & EOL & "a#2" & EOL,
         "sort -d output");

      Context.Initialize ("sort", Two_Args ("-cd", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a#2" & EOL & "a!1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -cd rejects dictionary unordered input");

      Context.Initialize ("sort", Two_Args ("-i", "-"));
      Test_Contexts.Set_Standard_Input
        (Context, "a" & Character'Val (1) & "2" & EOL & "a1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a1" & EOL & "a" & Character'Val (1) & "2" & EOL,
         "sort -i output");

      Context.Initialize ("sort", Two_Args ("-ci", "-"));
      Test_Contexts.Set_Standard_Input
        (Context, "a" & Character'Val (1) & "2" & EOL & "a1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -ci rejects ignore-nonprinting unordered input");

      Context.Initialize ("sort", Two_Args ("-k2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b 2" & EOL & "a 1" & EOL & "c 3" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 1" & EOL & "b 2" & EOL & "c 3" & EOL,
         "sort -k attached field key output");

      Context.Initialize ("sort", Two_Args ("-k2", "-"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "x d" & EOL & "x ch" & EOL & "x c" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "x c" & EOL & "x ch" & EOL & "x d" & EOL,
         "sort -k uses locale collation order");

      Context.Initialize ("sort", Four_Args ("-t", ":", "-k", "2"));
      Test_Contexts.Set_Standard_Input (Context, "x:b" & EOL & "z:a" & EOL & "y:c" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "z:a" & EOL & "x:b" & EOL & "y:c" & EOL,
         "sort -t -k separated field key output");

      Context.Initialize ("sort", Two_Args ("-k2,2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 2 z" & EOL & "b 1 y" & EOL & "c 3 x" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b 1 y" & EOL & "a 2 z" & EOL & "c 3 x" & EOL,
         "sort -k start end field key output");

      Context.Initialize ("sort", Two_Args ("-k1.2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "x3" & EOL & "z1" & EOL & "y2" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "z1" & EOL & "y2" & EOL & "x3" & EOL,
         "sort -k start character key output");

      Context.Initialize ("sort", Three_Args ("-k", "2.2,2.2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a b3" & EOL & "b a1" & EOL & "c c2" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b a1" & EOL & "c c2" & EOL & "a b3" & EOL,
         "sort -k separated character range output");

      Context.Initialize ("sort", Three_Args ("-n", "-k2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 10" & EOL & "b 2" & EOL & "c -1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "c -1" & EOL & "b 2" & EOL & "a 10" & EOL,
         "sort -n -k field key output");

      Context.Initialize ("sort", Two_Args ("-k2n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 10" & EOL & "b 2" & EOL & "c -1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "c -1" & EOL & "b 2" & EOL & "a 10" & EOL,
         "sort -k numeric modifier output");

      Context.Initialize ("sort", Two_Args ("-k1f", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "B" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL & "B" & EOL,
         "sort -k fold-case modifier output");

      Context.Initialize ("sort", Two_Args ("-k1d", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a#2" & EOL & "a 10" & EOL & "a!1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 10" & EOL & "a!1" & EOL & "a#2" & EOL,
         "sort -k dictionary modifier output");

      Context.Initialize ("sort", Two_Args ("-k1i", "-"));
      Test_Contexts.Set_Standard_Input
        (Context, "a" & Character'Val (1) & "2" & EOL & "a1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a1" & EOL & "a" & Character'Val (1) & "2" & EOL,
         "sort -k ignore-nonprinting modifier output");

      Context.Initialize ("sort", Four_Args ("-t", ":", "-k", "2b"));
      Test_Contexts.Set_Standard_Input (Context, "a:  b" & EOL & "b: a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b: a" & EOL & "a:  b" & EOL,
         "sort -k ignore-leading-blanks modifier output");

      Context.Initialize ("sort", Two_Args ("-k1r", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & EOL & "a" & EOL,
         "sort -k reverse modifier output");

      Context.Initialize ("sort", Three_Args ("-k1,1", "-k2n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b 2" & EOL & "b 1" & EOL & "a 3" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 3" & EOL & "b 1" & EOL & "b 2" & EOL,
         "sort multiple keys output");

      Context.Initialize ("sort", Three_Args ("-k1,1", "-k2nr", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 1" & EOL & "a 3" & EOL & "b 2" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 3" & EOL & "a 1" & EOL & "b 2" & EOL,
         "sort multiple keys reverse numeric output");

      Context.Initialize ("sort", Two_Args ("-m", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "c" & EOL & "b" & EOL & "d" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL & "c" & EOL & "d" & EOL,
         "sort -m output");

      Context.Initialize ("sort", Two_Args ("-k0", "-"));
      Test_Contexts.Set_Standard_Input (Context, "data" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sort rejects zero key field");

      Context.Initialize ("sort", Two_Args ("-k999999999999999999999999999999", "-"));
      Test_Contexts.Set_Standard_Input (Context, "data" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sort rejects overflowing key field");

      Context.Initialize ("sort", Two_Args ("-k3,2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "data" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sort rejects decreasing key field range");

      Context.Initialize ("sort", Two_Args ("-k2.3,2.2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "data" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sort rejects decreasing key character range");

      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "10 ten" & EOL & " 2 two" & EOL & "-1 minus" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-1 minus" & EOL & " 2 two" & EOL & "10 ten" & EOL,
         "sort -n output");

      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "2.50 two" & EOL & "-1.25 minus" & EOL & "2.05 low" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-1.25 minus" & EOL & "2.05 low" & EOL & "2.50 two" & EOL,
         "sort -n decimal output");

      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context, "2,50 two" & EOL & "-1,25 minus" & EOL & "2,05 low" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-1,25 minus" & EOL & "2,05 low" & EOL & "2,50 two" & EOL,
         "sort -n uses locale decimal separator");

      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         "1e3 high" & EOL
         & "2.5e-1 low" & EOL
         & "-1e2 minus" & EOL
         & "3 middle" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
         "-1e2 minus" & EOL
         & "2.5e-1 low" & EOL
         & "3 middle" & EOL
         & "1e3 high" & EOL,
         "sort -n exponent output");

      Context.Initialize ("sort", Two_Args ("-ns", "-"));
      Test_Contexts.Set_Standard_Input (Context, "2 z" & EOL & "2 a" & EOL & "1 one" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1 one" & EOL & "2 z" & EOL & "2 a" & EOL,
         "sort -ns preserves equal numeric input order");

      Context.Initialize ("sort", Two_Args ("-ub", "-"));
      Test_Contexts.Set_Standard_Input (Context, " apple" & EOL & "  apple" & EOL & "banana" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = " apple" & EOL & "banana" & EOL,
         "sort -ub output");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "sort -c accepts ordered input");

      Context.Initialize ("sort", Two_Args ("-cn", "-"));
      Test_Contexts.Set_Standard_Input (Context, "1.5" & EOL & "1.25" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -cn rejects decimal unordered input");

      Context.Initialize ("sort", Two_Args ("-cn", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input (Context, "1,5" & EOL & "1,25" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -cn uses locale decimal separator");

      Context.Initialize ("sort", Two_Args ("-cns", "-"));
      Test_Contexts.Set_Standard_Input (Context, "2 z" & EOL & "2 a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "sort -cns accepts stable equal numeric input order");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -c rejects unordered input");

      Context.Initialize ("sort", Two_Args ("-Cr", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "sort -Cr accepts reverse ordered input");

      Context.Initialize ("sort", Two_Args ("-cu", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -cu rejects duplicates");

      Context.Initialize ("sort", Three_Args ("-o", Sort_Out, Source));
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Ada.Directories.Exists (Sort_Out), "sort -o output file");
      Context.Initialize ("cat", One_Arg (Sort_Out));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "copy-data" & EOL,
         "sort -o writes sorted file data");

      Context.Initialize ("sort", Three_Args ("-o", Made, Source));
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -o reports output-file failure");

      Remove_Any (Option_Dir);
      Ada.Directories.Create_Directory (Option_Dir);
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "b" & EOL);
      Write_File (Hostkit.Fs.Join (Option_Dir, "-r"), "a" & EOL);
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);
         Context.Initialize ("sort", Two_Args ("plain", "-r"));
         Posix_Tools.Commands.Sort.Run (Context, Result);
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL,
         "sort treats option-like words after first file operand as file operands");

      Remove_Any (Option_Dir);
      Ada.Directories.Create_Directory (Option_Dir);
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "x" & EOL);
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);
         Context.Initialize ("uniq", Two_Args ("plain", "-c"));
         Posix_Tools.Commands.Uniq.Run (Context, Result);
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Ada.Directories.Exists (Hostkit.Fs.Join (Option_Dir, "-c")),
         "uniq treats option-like words after first file operand as file operands");

      Context.Initialize ("cat", One_Arg (Hostkit.Fs.Join (Option_Dir, "-c")));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "x" & EOL,
         "uniq output operand receives filtered data");

      Context.Initialize ("uniq", Two_Args (Source, Made));
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "uniq reports output-file failure");

      Context.Initialize ("tee", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "tee-data");
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "tee-data", "tee output");

      Write_File (Tee_Out, "old");
      Context.Initialize ("tee", Three_Args ("-ai", "--", Tee_Out));
      Test_Contexts.Set_Standard_Input (Context, "new");
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "new", "tee -ai stdout");
      Context.Initialize ("cat", One_Arg (Tee_Out));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "oldnew", "tee -a appends file");

      if Posix_Tools.Host_Adapters.Signals.Is_Supported (Posix_Tools.Host_Adapters.Signals.Interrupt) then
         declare
            Before : Posix_Tools.Host_Adapters.Signals.Disposition;
            After  : Posix_Tools.Host_Adapters.Signals.Disposition;
            Got_Before : constant Boolean :=
              Posix_Tools.Host_Adapters.Signals.Current_Disposition
                (Posix_Tools.Host_Adapters.Signals.Interrupt, Before);
         begin
            AUnit.Assertions.Assert (Got_Before, "tee -i can inspect interrupt disposition");
            Context.Initialize ("tee", Two_Args ("-i", "--"));
            Test_Contexts.Set_Standard_Input (Context, "signal-safe");
            Posix_Tools.Commands.Tee.Run (Context, Result);
            AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tee -i status");
            AUnit.Assertions.Assert
              (Posix_Tools.Host_Adapters.Signals.Current_Disposition
                 (Posix_Tools.Host_Adapters.Signals.Interrupt, After)
               and then After = Before,
               "tee -i restores interrupt disposition");
         end;
      end if;

      Context.Initialize ("tee", One_Arg (Made));
      Test_Contexts.Set_Standard_Input (Context, "blocked");
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "blocked"
         and then Ada.Strings.Fixed.Index (Test_Contexts.Error_Output (Context), Made) > 0,
         "tee reports failed file output");

      Context.Initialize ("tee", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "blocked");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tee reports standard-output failure");

      Context.Initialize ("tee", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 3);
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "abc",
         "tee streams readable prefix before input failure");

      Context.Initialize ("tee", One_Arg ("-z"));
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tee validates options before reading stdin");

      Context.Initialize ("tr", Two_Args ("abc", "xyz"));
      Test_Contexts.Set_Standard_Input (Context, "cab");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zxy", "tr output");

      Context.Initialize ("tr", Two_Args ("a-c", "x-z"));
      Test_Contexts.Set_Standard_Input (Context, "cab");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zxy", "tr range output");

      Context.Initialize ("tr", Two_Args ("\n\t", "NL"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & Character'Val (9) & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "aNLb", "tr control escape output");

      Context.Initialize ("tr", Two_Args ("\\", "/"));
      Test_Contexts.Set_Standard_Input (Context, "a\b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a/b", "tr backslash escape output");

      Context.Initialize ("tr", Two_Args ("\101\102", "xy"));
      Test_Contexts.Set_Standard_Input (Context, "ABC");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xyC", "tr octal escape output");

      Context.Initialize ("tr", Two_Args ("\141-\143", "x-z"));
      Test_Contexts.Set_Standard_Input (Context, "cab");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zxy", "tr octal range output");

      Context.Initialize ("tr", Two_Args ("\011-\012", "TN"));
      Test_Contexts.Set_Standard_Input (Context, Character'Val (9) & Character'Val (10) & "x");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "TNx", "tr control range output");

      Context.Initialize ("tr", Two_Args ("-d", "\n"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "tr delete newline escape output");

      Context.Initialize ("tr", Two_Args ("[:lower:]", "[:upper:]"));
      Test_Contexts.Set_Standard_Input (Context, "a1z");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "A1Z", "tr lower upper class output");

      Context.Initialize ("tr", Two_Args ("-d", "[:digit:]"));
      Test_Contexts.Set_Standard_Input (Context, "a1b2");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "tr digit class delete output");

      Context.Initialize ("tr", Two_Args ("-d", "[:xdigit:]"));
      Test_Contexts.Set_Standard_Input (Context, "aFgZ19-");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "gZ-", "tr xdigit class delete output");

      Context.Initialize ("tr", Two_Args ("-d", "[:punct:]"));
      Test_Contexts.Set_Standard_Input (Context, "a,b.c!");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "tr punct class delete output");

      Context.Initialize ("tr", Two_Args ("-s", "[:blank:]"));
      Test_Contexts.Set_Standard_Input (Context, "a  " & Character'Val (9) & Character'Val (9) & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a " & Character'Val (9) & "b",
         "tr blank class squeeze output");

      Context.Initialize ("tr", Two_Args ("[:cntrl:]", "?"));
      Test_Contexts.Set_Standard_Input (Context, "a" & Character'Val (0) & Character'Val (127));
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a??", "tr cntrl class translate output");

      Context.Initialize ("tr", Two_Args ("-cd", "[:print:]"));
      Test_Contexts.Set_Standard_Input (Context, "a" & Character'Val (0) & " ");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a ", "tr print class complement output");

      Context.Initialize ("tr", Two_Args ("-d", "a-c"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "d", "tr delete range output");

      Context.Initialize ("tr", Two_Args ("-cd", "a-c"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ca", "tr delete complement output");

      Context.Initialize ("tr", Three_Args ("-c", "a-c", "X"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "caX", "tr complement translate output");

      Context.Initialize ("tr", Three_Args ("-c", "a-c", "XY"));
      Test_Contexts.Set_Standard_Input (Context, Character'Val (0) & "d");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "XY", "tr ordered complement translate output");

      Context.Initialize ("tr", Three_Args ("-C", "a-c", "X"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "caX", "tr uppercase complement translate output");

      Test_Contexts.Set_Locale (Context, "da");
      Context.Initialize ("tr", Three_Args ("-c", "a-c", "XYZ"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input (Context, "defA");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XYZZ",
         "tr locale collation orders complement translation");

      Context.Initialize ("tr", Two_Args ("-s", "a-c"));
      Test_Contexts.Set_Standard_Input (Context, "aaabbbdd");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abdd", "tr squeeze output");

      Context.Initialize ("tr", Three_Args ("-s", "a-c", "x"));
      Test_Contexts.Set_Standard_Input (Context, "abcccd");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xd", "tr translate squeeze output");

      Context.Initialize ("tr", Three_Args ("-ds", "a-c", "d"));
      Test_Contexts.Set_Standard_Input (Context, "abdddde");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "de", "tr delete squeeze output");

      Context.Initialize ("tr", Two_Args ("abc", "[x*3]"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xxx", "tr repeated set output");

      Context.Initialize ("tr", Two_Args ("abc", "[x*]"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xxx", "tr shorthand repeated set output");

      Context.Initialize ("tr", Two_Args ("a-i", "[x*010]y"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "xxxxxxxxy",
         "tr leading-zero repeat count is octal");

      Context.Initialize ("tr", Two_Args ("a", "[x*999999999999999999999999999999999999999]"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "[",
         "tr overflowing repeat count falls back to literal bracket");

      Context.Initialize ("tr", Three_Args ("-c", "a-c", "[z*]"));
      Test_Contexts.Set_Standard_Input (Context, Character'Val (0) & "d");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zz", "tr shorthand repeat covers complement domain");

      Context.Initialize ("tr", Two_Args ("abc", "[\n*2]"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = EOL & EOL & EOL,
         "tr repeated escaped set output");

      Context.Initialize ("tr", Two_Args ("[=a=][.b.]", "xy"));
      Test_Contexts.Set_Standard_Input (Context, "aba");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "xyx",
         "tr single-byte equivalence and collating output");

      Context.Initialize ("tr", Two_Args ("[=\n=]", "N"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "aNb", "tr escaped equivalence output");

      Context.Initialize ("tr", Two_Args ("[=a=]", "X"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "a" & Character'Val (16#C3#) & Character'Val (16#A1#) & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XXXb",
         "tr locale equivalence expands accented UTF-8 bytes");

      Context.Initialize ("tr", Two_Args ("[.ab.][=cd=]", "XY"));
      Test_Contexts.Set_Standard_Input (Context, "abcd");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XYYY",
         "tr multibyte identity bracket output");

      Context.Initialize ("tr", Two_Args ("[.ch.]", "X"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "chico");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XXiXo",
         "tr locale collating symbol expands as a multibyte element");

      Context.Initialize ("tr", Two_Args ("[.a\n.]", "XY"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL);
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XY",
         "tr escaped multibyte collating output");

      Context.Initialize ("tr", Two_Args ("abc", "xyz"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Output_Failure_After (Context, 1);
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tr output failure status");

      Context.Initialize ("uniq", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL, "uniq output");

      Context.Initialize ("uniq", One_Arg ("-c"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "      2 a" & EOL & "      1 b" & EOL,
         "uniq -c output");

      Context.Initialize ("uniq", One_Arg ("-d"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL, "uniq -d output");

      Context.Initialize ("uniq", One_Arg ("-u"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & EOL, "uniq -u output");

      Context.Initialize ("uniq", Two_Args ("-f", "1"));
      Test_Contexts.Set_Standard_Input (Context, "1 same" & EOL & "2 same" & EOL & "3 other" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1 same" & EOL & "3 other" & EOL,
         "uniq -f output");

      Context.Initialize ("uniq", Two_Args ("-f", "1"));
      Test_Contexts.Set_Standard_Input
        (Context,
         "1" & Character'Val (16#C2#) & Character'Val (16#A0#) & "same" & EOL
         & "2" & Character'Val (16#C2#) & Character'Val (16#A0#) & "same" & EOL
         & "3" & Character'Val (16#C2#) & Character'Val (16#A0#) & "other" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "1" & Character'Val (16#C2#) & Character'Val (16#A0#) & "same" & EOL
           & "3" & Character'Val (16#C2#) & Character'Val (16#A0#) & "other" & EOL,
         "uniq -f uses Unicode whitespace");

      Context.Initialize ("uniq", One_Arg ("-s1"));
      Test_Contexts.Set_Standard_Input (Context, "asame" & EOL & "bsame" & EOL & "cother" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "asame" & EOL & "cother" & EOL,
         "uniq -s output");

      Context.Initialize ("uniq", One_Arg ("-s1"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A6#) & "same" & EOL
         & Character'Val (16#C3#) & Character'Val (16#B8#) & "same" & EOL
         & Character'Val (16#C3#) & Character'Val (16#A5#) & "other" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C3#) & Character'Val (16#A6#) & "same" & EOL
           & Character'Val (16#C3#) & Character'Val (16#A5#) & "other" & EOL,
         "uniq -s skips UTF-8 characters");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input (Context, "Alpha" & EOL & "alpha" & EOL & "Beta" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "Alpha" & EOL & "Beta" & EOL,
         "uniq -i output");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#CE#) & Character'Val (16#A3#) & EOL
         & Character'Val (16#CF#) & Character'Val (16#83#) & EOL
         & Character'Val (16#D0#) & Character'Val (16#AF#) & EOL
         & Character'Val (16#D1#) & Character'Val (16#8F#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#CE#) & Character'Val (16#A3#) & EOL
           & Character'Val (16#D0#) & Character'Val (16#AF#) & EOL,
         "uniq -i folds UTF-8 Greek and Cyrillic case pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C4#) & Character'Val (16#80#) & EOL
         & Character'Val (16#C4#) & Character'Val (16#81#) & EOL
         & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
         & Character'Val (16#D5#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#83#) & Character'Val (16#90#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C4#) & Character'Val (16#80#) & EOL
           & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
           & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL,
         "uniq -i folds UTF-8 Latin Extended Armenian and Georgian pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C6#) & Character'Val (16#81#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#93#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#94#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#90#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#9B#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C6#) & Character'Val (16#81#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#90#) & EOL,
         "uniq -i folds UTF-8 Latin Extended-B pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL
         & Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#A8#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL,
         "uniq -i folds UTF-8 Deseret pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
         & Character'Val (16#EA#) & Character'Val (16#AD#) & Character'Val (16#B0#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BD#) & Character'Val (16#81#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
           & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL,
         "uniq -i folds UTF-8 Cherokee and Fullwidth Latin pairs");

      Context.Initialize ("uniq", One_Arg ("-ci"));
      Test_Contexts.Set_Standard_Input (Context, "Alpha" & EOL & "alpha" & EOL & "Beta" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "      2 Alpha" & EOL & "      1 Beta" & EOL,
         "uniq grouped -ci output");

      Context.Initialize ("uniq", One_Arg ("-c"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A5#) & EOL
         & Character'Val (16#E2#) & Character'Val (16#84#) & Character'Val (16#AB#) & EOL
         & "z" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "      2 " & Character'Val (16#C3#) & Character'Val (16#A5#) & EOL
           & "      1 z" & EOL,
         "uniq uses Danish locale collation equivalence");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "Ch" & EOL & "ch" & EOL & "d" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "Ch" & EOL & "d" & EOL,
         "uniq -i uses locale collation key after case folding");

      Context.Initialize ("uniq", Two_Args ("-i", "-s1"));
      Test_Contexts.Set_Standard_Input (Context, "xAlpha" & EOL & "yalpha" & EOL & "zBeta" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "xAlpha" & EOL & "zBeta" & EOL,
         "uniq -i -s output");

      Context.Initialize ("uniq", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL);
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "uniq output failure status");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b" & EOL, "xargs output");

      Context.Initialize ("xargs", Two_Args ("--", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b" & EOL, "xargs honors end-of-options");

      Context.Initialize ("xargs", Three_Args ("echo", "-n1", "fixed"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-n1 fixed a b" & EOL,
         "xargs stops option parsing after utility operand");

      Context.Initialize ("xargs", Two_Args ("-r", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "xargs -r skips empty input");

      Context.Initialize ("xargs", Two_Args ("--no-run-if-empty", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "   " & Character'Val (9));
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "xargs long no-run skips blank input");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a   b" & Character'Val (9) & "c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c" & EOL, "xargs collapses blanks");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a 'b c' ""d e""");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c d e" & EOL, "xargs quote grouping");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a 'b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects unmatched single quote");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a ""b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects unmatched double quote");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a\ b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c" & EOL, "xargs backslash grouping");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a\");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects trailing backslash");

      Context.Initialize ("xargs", Two_Args ("-n1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "'a b' c\ d");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL & "c d" & EOL,
         "xargs grouped operands batch as single items");

      Context.Initialize ("xargs", Three_Args ("-n", "2", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL & "c" & EOL,
         "xargs -n output");

      Context.Initialize ("xargs", Three_Args ("-s", "11", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "aa bb cc");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "aa bb" & EOL & "cc" & EOL,
         "xargs -s splits by composed command size");

      Context.Initialize ("xargs", Two_Args ("-s9", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "aa bb");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "aa" & EOL & "bb" & EOL,
         "xargs compact -s splits by composed command size");

      Context.Initialize ("xargs", Two_Args ("-t", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a b" & EOL
         and then Test_Contexts.Error_Output (Context) = "echo a b" & EOL,
         "xargs -t traces composed command");

      Context.Initialize ("xargs", Two_Args ("-t", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "xargs -t reports trace output failure");

      Context.Initialize ("xargs", Four_Args ("-x", "-s", "11", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "aa bb cc");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "xargs -x fails instead of splitting oversized batch");

      Context.Initialize ("xargs", Two_Args ("-s", "0"));
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects zero command size");

      Context.Initialize ("xargs", Four_Args ("-I", "{}", "echo", "file-{}"));
      Test_Contexts.Set_Standard_Input (Context, "one two" & EOL & "three" & EOL);
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file-one two" & EOL & "file-three" & EOL,
         "xargs -I replacement output");

      Context.Initialize ("xargs", Three_Args ("-I{}", "echo", "{}/suffix"));
      Test_Contexts.Set_Standard_Input (Context, "root" & EOL);
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "root/suffix" & EOL,
         "xargs compact -I replacement output");

      Context.Initialize ("xargs", One_Arg ("-I"));
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects missing -I replacement string");

      Context.Initialize ("xargs", Three_Args ("-E", "STOP", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b STOP c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL,
         "xargs -E output");

      Context.Initialize ("xargs", Five_Args ("-E", "STOP", "-n", "1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a STOP c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL,
         "xargs -E -n output");

      Context.Initialize ("xargs", Two_Args ("-0", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b" & Character'Val (0) & "c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c" & EOL, "xargs -0 output");

      Context.Initialize ("xargs", Four_Args ("-0", "-n", "1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b" & Character'Val (0) & "c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL & "c" & EOL,
         "xargs -0 -n output");

      Context.Initialize ("xargs", Two_Args ("-n1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL,
         "xargs compact -n output");

      Context.Initialize ("xargs", One_Arg ("false"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Xargs_Utility_Failed,
         "xargs classifies non-zero utility status");

      Context.Initialize ("xargs", One_Arg ("xargs-status-255"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Xargs_Utility_Requested_Stop,
         "xargs classifies utility status 255");

      Context.Initialize ("xargs", One_Arg ("xargs-cannot-invoke"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Cannot_Invoke,
         "xargs classifies utility status 126");

      Context.Initialize ("xargs", One_Arg ("missing-utility"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Not_Found,
         "xargs classifies missing utility");

      Context.Initialize ("date", No_Args);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context)'Length > 1, "date output");

      Context.Initialize ("date", One_Arg ("+%%"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "%" & EOL, "date escaped percent output");

      Context.Initialize ("date", One_Arg ("+blocked"));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "date reports standard-output failure");

      Context.Initialize ("date", One_Arg ("+literal"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "literal" & EOL, "date literal format output");

      Context.Initialize ("date", Two_Args ("--", "+%Y"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 5
            and then (for all I in Output'First .. Output'First + 3 => Output (I) in '0' .. '9')
            and then Output (Output'Last) = EOL,
            "date honors end-of-options before format");
      end;

      Context.Initialize ("date", One_Arg ("+%F %T %R %y"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 29
            and then Output (Output'First + 4) = '-'
            and then Output (Output'First + 7) = '-'
            and then Output (Output'First + 10) = ' '
            and then Output (Output'First + 13) = ':'
            and then Output (Output'First + 16) = ':'
            and then Output (Output'First + 19) = ' '
            and then Output (Output'First + 22) = ':'
            and then Output (Output'First + 25) = ' '
            and then Output (Output'First + 28) = EOL,
            "date composite format output");
      end;

      Context.Initialize ("date", One_Arg ("+%x %X"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 18
            and then Output (Output'First + 2) = '/'
            and then Output (Output'First + 5) = '/'
            and then Output (Output'First + 8) = ' '
            and then Output (Output'First + 11) = ':'
            and then Output (Output'First + 14) = ':'
            and then Output (Output'First + 17) = EOL,
            "date localized composite shape output");
      end;

      Context.Initialize ("date", One_Arg ("+%c"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length >= 25
            and then Contains (Output, ":")
            and then not Contains (Output, "%c")
            and then Output (Output'Last) = EOL,
            "date full composite output");
      end;

      Context.Initialize ("date", One_Arg ("+%C %D %e %I %k %l %p %r %u %w %j"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 47
            and then Output (Output'First + 2) = ' '
            and then Output (Output'First + 5) = '/'
            and then Output (Output'First + 8) = '/'
            and then Output (Output'First + 11) = ' '
            and then Output (Output'First + 14) = ' '
            and then Output (Output'First + 17) = ' '
            and then Output (Output'First + 20) = ' '
            and then Output (Output'First + 23) = ' '
            and then Output (Output'First + 26) = ' '
            and then Output (Output'First + 29) = ':'
            and then Output (Output'First + 32) = ':'
            and then Output (Output'First + 35) = ' '
            and then Output (Output'First + 38) = ' '
            and then Output (Output'First + 40) = ' '
            and then Output (Output'First + 42) = ' '
            and then Output (Output'First + 46) = EOL,
            "date extended numeric format output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);

         function Has_Word (Needle : String) return Boolean is
         begin
            return Contains (Output, Needle & " ") or else Contains (Output, " " & Needle & EOL);
         end Has_Word;
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "Mon ") or else Contains (Output, "Tue ") or else Contains (Output, "Wed ")
             or else Contains (Output, "Thu ") or else Contains (Output, "Fri ") or else Contains (Output, "Sat ")
             or else Contains (Output, "Sun "))
            and then (Has_Word ("January") or else Has_Word ("February") or else Has_Word ("March")
              or else Has_Word ("April") or else Has_Word ("May") or else Has_Word ("June")
              or else Has_Word ("July") or else Has_Word ("August") or else Has_Word ("September")
              or else Has_Word ("October") or else Has_Word ("November") or else Has_Word ("December")),
            "date weekday and month names output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "mandag") or else Contains (Output, "tirsdag")
             or else Contains (Output, "onsdag") or else Contains (Output, "torsdag")
             or else Contains (Output, "fredag") or else Contains (Output, "lørdag")
             or else Contains (Output, "søndag"))
            and then (Contains (Output, "januar") or else Contains (Output, "februar")
              or else Contains (Output, "marts") or else Contains (Output, "april")
              or else Contains (Output, "maj") or else Contains (Output, "juni")
              or else Contains (Output, "juli") or else Contains (Output, "august")
              or else Contains (Output, "september") or else Contains (Output, "oktober")
              or else Contains (Output, "november") or else Contains (Output, "december")),
            "date Danish weekday and month names output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Test_Contexts.Set_Locale (Context, "es");
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "lunes") or else Contains (Output, "martes")
             or else Contains (Output, "miercoles") or else Contains (Output, "jueves")
             or else Contains (Output, "viernes") or else Contains (Output, "sabado")
             or else Contains (Output, "domingo"))
            and then (Contains (Output, "enero") or else Contains (Output, "febrero")
              or else Contains (Output, "marzo") or else Contains (Output, "abril")
              or else Contains (Output, "mayo") or else Contains (Output, "junio")
              or else Contains (Output, "julio") or else Contains (Output, "agosto")
              or else Contains (Output, "septiembre") or else Contains (Output, "octubre")
              or else Contains (Output, "noviembre") or else Contains (Output, "diciembre")),
            "date Spanish weekday and month names output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Test_Contexts.Set_Locale (Context, "zz");
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "Mon ") or else Contains (Output, "Tue ") or else Contains (Output, "Wed ")
             or else Contains (Output, "Thu ") or else Contains (Output, "Fri ") or else Contains (Output, "Sat ")
             or else Contains (Output, "Sun "))
            and then not Contains (Output, "posix_tools.date."),
            "date unknown locale falls back without message-key leak");
      end;

      Context.Initialize ("date", One_Arg ("+%b %h"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 8
            and then Output (Output'First .. Output'First + 2) =
              Output (Output'First + 4 .. Output'First + 6)
            and then Output (Output'Last) = EOL,
            "date %h aliases abbreviated month name");
      end;

      Context.Initialize ("date", One_Arg ("+%G-%g-%V"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 11
            and then Output (Output'First + 4) = '-'
            and then Output (Output'First + 7) = '-'
            and then not Contains (Output, "%G")
            and then not Contains (Output, "%g")
            and then not Contains (Output, "%V")
            and then Output (Output'Last) = EOL,
            "date ISO week format output");
      end;

      Context.Initialize ("date", One_Arg ("+%U %W"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 6
            and then Output (Output'First) in '0' .. '9'
            and then Output (Output'First + 1) in '0' .. '9'
            and then Output (Output'First + 2) = ' '
            and then Output (Output'First + 3) in '0' .. '9'
            and then Output (Output'First + 4) in '0' .. '9'
            and then Output (Output'Last) = EOL
            and then not Contains (Output, "%U")
            and then not Contains (Output, "%W"),
            "date POSIX week number output");
      end;

      Context.Initialize ("date", One_Arg ("+%z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 6
            and then Output (Output'First) in '+' | '-'
            and then Output (Output'First + 1) in '0' .. '9'
            and then Output (Output'First + 2) in '0' .. '9'
            and then Output (Output'First + 3) in '0' .. '9'
            and then Output (Output'First + 4) in '0' .. '9'
            and then Output (Output'First + 5) = EOL,
            "date timezone offset output");
      end;

      Context.Initialize ("date", Two_Args ("-u", "+%z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000" & EOL, "date -u timezone output");

      Context.Initialize ("date", Two_Args ("-u", "+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "CET-1");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0000 UTC" & EOL,
         "date -u overrides TZ fixed offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "UTC0");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ UTC output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "GMT+00:00");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ signed colon UTC output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "UTC-0000");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ signed compact UTC output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "UTC+02:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0230 UTC" & EOL, "date TZ positive fixed offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "GMT-0330");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "-0330 GMT" & EOL, "date TZ negative fixed offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "CET-1");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "-0100 CET" & EOL, "date TZ named hour offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "EST5EDT");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0500 EST" & EOL,
         "date TZ ignores DST suffix after standard offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "EST5EDT,M3.2.0,M11.1.0");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0500 EST" & EOL,
         "date TZ ignores DST transition rules after standard offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "FOO+02:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0230 FOO" & EOL, "date TZ named colon offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "<UTC+1>+02:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0230 UTC+1" & EOL,
         "date TZ quoted non-alphabetic name output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "<-0330>-03:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-0330 -0330" & EOL,
         "date TZ quoted signed name output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "BAR0");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 BAR" & EOL, "date TZ named zero offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "Etc/UTC");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ i18n UTC zone");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "Asia/Kolkata");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0530 IST" & EOL
         or else Test_Contexts.Output (Context) = "+0530 Asia/Kolkata" & EOL,
         "date TZ i18n regional zone");

      Context.Initialize ("date", Two_Args ("-u", "+%Z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "UTC" & EOL, "date -u timezone name output");

      Context.Initialize ("date", One_Arg ("+%Z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 6
            and then Output (Output'First) in '+' | '-'
            and then Output (Output'First + 1) in '0' .. '9'
            and then Output (Output'First + 2) in '0' .. '9'
            and then Output (Output'First + 3) in '0' .. '9'
            and then Output (Output'First + 4) in '0' .. '9'
            and then Output (Output'First + 5) = EOL,
            "date local timezone name fallback output");
      end;

      Context.Initialize ("date", Two_Args ("-u", "+%F %T"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 20
            and then Output (Output'First + 4) = '-'
            and then Output (Output'First + 7) = '-'
            and then Output (Output'First + 10) = ' '
            and then Output (Output'First + 13) = ':'
            and then Output (Output'First + 16) = ':'
            and then Output (Output'First + 19) = EOL,
            "date -u timestamp shape");
      end;

      Context.Initialize ("date", One_Arg ("+%s"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length >= 2
            and then Output (Output'Last) = EOL
            and then (for all I in Output'First .. Output'Last - 1 => Output (I) in '0' .. '9'),
            "date epoch seconds output");
      end;

      Context.Initialize ("date", Two_Args ("-u", "010203042026.05"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "date set operand status");
      AUnit.Assertions.Assert (Test_Contexts.Date_Set_Called (Context), "date set operand calls context setter");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "2026")
         and then Contains (Test_Contexts.Output (Context), "03:04:05"),
         "date set operand reports selected timestamp");

      Context.Initialize ("date", Two_Args ("-u", "01020304"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "date set operand current year status");

      Context.Initialize ("date", Two_Args ("-u", "0102030469"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "1969"),
         "date set operand maps two-digit year 69 to 1969");

      Context.Initialize ("date", Two_Args ("-u", "0102030468"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "2068"),
         "date set operand maps two-digit year 68 to 2068");

      Context.Initialize ("date", One_Arg ("13320304"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "date rejects invalid set operand");

      Context.Initialize ("date", One_Arg ("010203042026"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "date reports failed system date set");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "date: cannot set system date" & EOL,
         "date set failure diagnostic");

      Context.Initialize ("env", Two_Args ("-i", "NAME=value"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "env status");
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "NAME=value" & EOL, "env -i assignment output");

      Context.Initialize ("env", Two_Args ("-i", "NAME=value"));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "env reports standard-output failure");

      Context.Initialize ("env", One_Arg ("B=3"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Test_Contexts.Set_Environment_Value (Context, "B", "2");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A=1" & EOL & "B=3" & EOL,
         "env inherited and replacement output");

      Context.Initialize ("env", Two_Args ("-u", "A"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Test_Contexts.Set_Environment_Value (Context, "B", "2");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "B=2" & EOL,
         "env -u removes inherited variable");

      Context.Initialize ("env", Three_Args ("-u", "A", "A=3"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A=3" & EOL,
         "env -u allows later replacement");

      Context.Initialize ("env", One_Arg ("-u"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "env -u missing operand status");

      Context.Initialize ("env", One_Arg ("-i"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "env -i empty output");

      Context.Initialize ("env", One_Arg ("=bad"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "env rejects empty name");

      Context.Initialize ("env", Three_Args ("-i", "--", "NAME=value"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "NAME=value" & EOL,
         "env accepts assignment after --");

      Context.Initialize ("env", Four_Args ("-i", "NAME=value", "printenv", "NAME"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "value" & EOL,
         "env executes utility with computed environment");

      Context.Initialize ("env", Two_Args ("-i", "false"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "env returns utility nonzero status");

      Context.Initialize ("env", Two_Args ("--", "-i"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Not_Found,
         "env treats option after -- as missing utility");

      Context.Initialize ("find", One_Arg (Source));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Source & EOL, "find file output");

      Context.Initialize ("find", One_Arg (Source));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "find reports standard-output failure");

      Context.Initialize ("find", Two_Args (Source, "-print"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Source & EOL, "find explicit -print output");

      Context.Initialize ("find", One_Arg ("-"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "-" & EOL,
         "find treats - as path operand");

      Context.Initialize ("find", Two_Args ("--", "-name"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "-name" & EOL,
         "find treats option-like operand after -- as path operand");

      Context.Initialize ("find", Three_Args (Made, "-name", "command-source.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -name output");

      Context.Initialize ("find", Three_Args (Made, "-name", "command-source.t?t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -name question wildcard output");

      Context.Initialize ("find", Three_Args (Made, "-name", "command-source.[tx][xq]t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -name bracket list output");

      Context.Initialize ("find", Three_Args (Made, "-name", "command-source.[a-z][a-z]t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -name bracket range output");

      Context.Initialize ("find", Three_Args (Made, "-name", "command-source.[!0-9][!0-9]t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -name negated bracket range output");

      Context.Initialize ("find", Three_Args (Tree, "-path", "*/sub/file.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "command-tree" & EOL),
         "find -path output");

      Context.Initialize ("find", Three_Args (Tree, "-type", "d"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-tree" & EOL)
         and then Contains (Test_Contexts.Output (Context), "sub" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -type d output");

      Context.Initialize ("find", Three_Args (Tree, "-type", "p"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "find exact FIFO type excludes ordinary tree entries");

      if Hostkit.Fs.Special_File_Info_Of (Cp_FIFO_Source).Kind = Hostkit.Fs.FIFO then
         Context.Initialize ("find", Three_Args (Cp_FIFO_Source, "-type", "p"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = Cp_FIFO_Source & EOL,
            "find -type p matches FIFO exactly");
      end if;

      if Hostkit.Fs.Special_File_Info_Of (Cp_Socket_Source).Kind = Hostkit.Fs.Socket then
         Context.Initialize ("find", Three_Args (Cp_Socket_Source, "-type", "s"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = Cp_Socket_Source & EOL,
            "find -type s matches socket exactly");
      end if;

      if Ada.Directories.Exists ("/dev/null")
        and then Hostkit.Fs.Special_File_Info_Of ("/dev/null").Kind = Hostkit.Fs.Character_Device
      then
         Context.Initialize ("find", Three_Args ("/dev/null", "-type", "c"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = "/dev/null" & EOL,
            "find -type c matches character device exactly");

         Context.Initialize ("find", Three_Args ("/dev/null", "-type", "b"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = "",
            "find -type b excludes character device");
      end if;

      Context.Initialize ("find", Three_Args (Made, "-size", "9c"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -size exact bytes output");

      Context.Initialize ("find", Three_Args (Made, "-size", "+8c"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -size greater bytes output");

      Context.Initialize ("find", Three_Args (Made, "-size", "-2"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -size less default blocks output");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-size", "bad"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects invalid -size count");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-size", "++1c"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects double-signed -size count");

      Write_File (Source, "copy-data");
      Write_File (Other, "old-data");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (Other,
         GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));

      Context.Initialize ("find", Three_Args (Source, "-mtime", "-1"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -mtime less than one day output");

      Context.Initialize ("find", Three_Args (Source, "-mtime", "+99999"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -mtime greater than large age excludes current file");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-mtime", "bad"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects invalid -mtime count");

      Context.Initialize ("find", Three_Args (Source, "-newer", Other));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
         "find -newer reference output");

      Context.Initialize ("find", Six_Args (Source, "-exec", "echo", "seen", "{}", ";"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "seen " & Source & EOL,
         "find -exec replacement output");

      Context.Initialize ("find", Four_Args (Source, "-exec", "false", ";"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "find -exec false suppresses default output");

      Context.Initialize ("find", Six_Args (Source, "-exec", "echo", "plus", "{}", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "plus " & Source & EOL,
         "find -exec plus replacement output");

      Context.Initialize ("find", Six_Args (Tree, "-exec", "echo", "batch", "{}", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "batch " & Tree & " " & Tree & "/sub "
           & Tree & "/sub/file.txt" & EOL,
         "find -exec plus batches matches");

      Context.Initialize ("find", Six_Args (Source, "-exec", "echo", "{}", "after", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects plus without preceding replacement");

      Context.Initialize ("find", Three_Args (Source, "-exec", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects missing utility before -exec plus");

      Context.Initialize ("find", Four_Args (Source, "-exec", "echo", "{}"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects unterminated -exec");

      Context.Initialize ("find", Six_Args (Source, "-ok", "echo", "ok", "{}", ";"));
      Test_Contexts.Set_Standard_Input (Context, "y" & EOL);
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ok " & Source & EOL
         and then Contains (Test_Contexts.Error_Output (Context), "< echo ... " & Source & " > ?"),
         "find -ok executes after affirmative response");

      Context.Initialize ("find", Six_Args (Source, "-ok", "echo", "ok", "{}", ";"));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Contains (Test_Contexts.Error_Output (Context), "< echo ... " & Source & " > ?"),
         "find -ok skips after negative response");

      Context.Initialize ("find", Four_Args (Source, "-ok", "echo", "{}"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects unterminated -ok");

      Context.Initialize ("find", Two_Args (Tree, "-depth"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Tree & "/sub/file.txt" & EOL
           & Tree & "/sub" & EOL
           & Tree & EOL,
         "find -depth post-order output");

      Context.Initialize ("find", Four_Args (Tree, "-name", "sub", "-prune"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "sub" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -prune skips subtree");

      Context.Initialize ("find", Two_Args (Tree, "-xdev"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), Tree & EOL)
         and then Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -xdev keeps traversal on the starting device");

      if Hostkit.Metadata.Permissions_Supported then
         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Tree & "/sub/file.txt", 8#640#),
            "find -perm file mode setup");
         Context.Initialize ("find", Three_Args (Tree, "-perm", "640"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm exact output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "-600"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm all-bits output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "u=rw,g=r,o="));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm symbolic exact output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "-u=rw"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm symbolic all-bits output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "bad"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
            "find rejects invalid -perm mode");
      end if;

      if Hostkit.Metadata.Ownership_Supported then
         declare
            User_Id : Natural;
            Group_Id : Natural;
            Available : Boolean;
         begin
            Hostkit.Metadata.File_Ownership (Source, User_Id, Group_Id, Available);
            if Available then
               declare
                  User_Raw : constant String := Natural'Image (User_Id);
                  Group_Raw : constant String := Natural'Image (Group_Id);
                  User_Text : constant String := User_Raw (User_Raw'First + 1 .. User_Raw'Last);
                  Group_Text : constant String := Group_Raw (Group_Raw'First + 1 .. Group_Raw'Last);
                  User_Name : constant String := Hostkit.Metadata.User_Name_For_Id (User_Id);
                  Group_Name : constant String := Hostkit.Metadata.Group_Name_For_Id (Group_Id);
               begin
                  Context.Initialize ("find", Three_Args (Source, "-user", User_Text));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
                     "find -user numeric output");

                  Context.Initialize ("find", Three_Args (Source, "-group", Group_Text));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
                     "find -group numeric output");

                  Context.Initialize
                    ("find", Three_Args (Source, "-user", "999999999999999999999999999999"));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Result.Status = Posix_Tools.Exit_Status.Success
                     and then not Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
                     "find overflowing numeric user does not match");

                  if User_Name /= "" then
                     Context.Initialize ("find", Three_Args (Source, "-user", User_Name));
                     Posix_Tools.Commands.Find.Run (Context, Result);
                     AUnit.Assertions.Assert
                       (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
                        "find -user named output");
                  end if;

                  if Group_Name /= "" then
                     Context.Initialize ("find", Three_Args (Source, "-group", Group_Name));
                     Posix_Tools.Commands.Find.Run (Context, Result);
                     AUnit.Assertions.Assert
                       (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL),
                        "find -group named output");
                  end if;

                  Context.Initialize ("find", Two_Args (Source, "-nouser"));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Result.Status = Posix_Tools.Exit_Status.Success
                     and then (User_Name = ""
                               or else not Contains
                                 (Test_Contexts.Output (Context), "command-source.txt" & EOL)),
                     "find -nouser output");

                  Context.Initialize ("find", Two_Args (Source, "-nogroup"));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Result.Status = Posix_Tools.Exit_Status.Success
                     and then (Group_Name = ""
                               or else not Contains
                                 (Test_Contexts.Output (Context), "command-source.txt" & EOL)),
                     "find -nogroup output");
               end;
            end if;
         end;
      end if;

      Context.Initialize ("find", Five_Args (Tree, "-type", "f", "-name", "file.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -type f -name output");

      Context.Initialize ("find", Six_Args (Tree, "-type", "f", "-a", "-name", "file.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "sub" & EOL),
         "find explicit and expression output");

      Context.Initialize
        ("find",
         Six_Args (Made, "-name", "command-source.txt", "-o", "-name", "command-other.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "command-source.txt" & EOL)
         and then Contains (Test_Contexts.Output (Context), "command-other.txt" & EOL),
         "find or expression output");

      Context.Initialize ("find", Four_Args (Tree, "!", "-type", "d"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "command-tree" & EOL),
         "find negated expression output");

      Context.Initialize ("find", Six_Args (Tree, "(", "-name", "file.txt", ")", "-print"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "command-tree" & EOL),
         "find parenthesized print expression output");

      if Hostkit.Fs.Is_Link (Symlinked) then
         Context.Initialize ("find", Three_Args (Symlinked, "-type", "l"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Symlinked & EOL,
            "find -type l output");
      end if;

      Context.Initialize ("test", One_Arg ("value"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test true status");

      Context.Initialize ("test", Two_Args ("-n", "value"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -n status");

      Context.Initialize ("test", Two_Args ("-z", ""));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -z status");

      Context.Initialize ("test", Two_Args ("-e", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -e file status");

      Context.Initialize ("test", Two_Args ("-d", Tree));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -d directory status");

      Context.Initialize ("test", Two_Args ("-f", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -f file status");

      Context.Initialize ("test", Two_Args ("-r", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -r readable file status");

      if Hostkit.Metadata.Permissions_Supported then
         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Source, 8#600#),
            "test writable source mode setup");
         Context.Initialize ("test", Two_Args ("-w", Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -w status");

         Context.Initialize ("test", Two_Args ("-x", Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -x false status");

         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Source, 8#700#),
            "test executable source mode setup");
         Context.Initialize ("test", Two_Args ("-x", Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -x status");

         if Hostkit.Metadata.Set_Permissions (Source, 8#4700#) then
            declare
               Available : Boolean;
               Mode      : constant Natural := Hostkit.Metadata.File_Permission_Bits (Source, Available);
            begin
               if Available and then (Mode / 8#4000#) mod 2 = 1 then
                  Context.Initialize ("test", Two_Args ("-u", Source));
                  Posix_Tools.Commands.Test_Command.Run (Context, Result);
                  AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -u status");
               end if;
            end;
         end if;

         if Hostkit.Metadata.Set_Permissions (Source, 8#2700#) then
            declare
               Available : Boolean;
               Mode      : constant Natural := Hostkit.Metadata.File_Permission_Bits (Source, Available);
            begin
               if Available and then (Mode / 8#2000#) mod 2 = 1 then
                  Context.Initialize ("test", Two_Args ("-g", Source));
                  Posix_Tools.Commands.Test_Command.Run (Context, Result);
                  AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -g status");
               end if;
            end;
         end if;

         if Hostkit.Metadata.Set_Permissions (Made, 8#1700#) then
            declare
               Available : Boolean;
               Mode      : constant Natural := Hostkit.Metadata.File_Permission_Bits (Made, Available);
            begin
               if Available and then (Mode / 8#1000#) mod 2 = 1 then
                  Context.Initialize ("test", Two_Args ("-k", Made));
                  Posix_Tools.Commands.Test_Command.Run (Context, Result);
                  AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -k status");
               end if;
            end;
         end if;

         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Source, 8#700#),
            "test source mode restore");
      end if;

      if Hostkit.Fs.Is_Link (Symlinked) then
         Context.Initialize ("test", Two_Args ("-h", Symlinked));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -h symlink status");

         Context.Initialize ("test", Two_Args ("-L", Symlinked));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -L symlink status");
      end if;

      Context.Initialize ("test", Three_Args (Source, "-ef", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -ef same file status");

      Context.Initialize ("test", Three_Args (Source, "-ef", Other));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -ef different file status");

      Context.Initialize ("test", Three_Args ("alpha", "<", "beta"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test string less-than status");

      Context.Initialize ("test", Three_Args ("z", "<", Character'Val (16#C3#) & Character'Val (16#A6#)));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "test string less-than uses locale collation");

      Context.Initialize ("test", Three_Args ("z", "<", Character'Val (16#C3#) & Character'Val (16#A6#)));
      Test_Contexts.Set_Locale (Context, "en");
      Test_Contexts.Set_Environment_Value (Context, "LC_COLLATE", "da");
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "test LC_COLLATE overrides context locale");

      Context.Initialize ("test", Three_Args ("beta", ">", "alpha"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test string greater-than status");

      Context.Initialize ("test", Three_Args ("alpha", ">", "beta"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test string greater-than false status");

      Context.Initialize ("test", Two_Args ("-r", No_Create));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -r missing file status");

      Context.Initialize ("test", Two_Args ("-s", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -s nonempty file status");

      Context.Initialize ("test", Two_Args ("-s", Empty));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -s empty file status");

      Context.Initialize ("test", Two_Args ("-s", No_Create));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -s missing file status");

      Context.Initialize ("test", Two_Args ("-b", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -b regular file status");

      Context.Initialize ("test", Two_Args ("-c", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -c regular file status");

      Context.Initialize ("test", Two_Args ("-p", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -p regular file status");

      Context.Initialize ("test", Two_Args ("-S", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -S regular file status");

      if Hostkit.Fs.Special_File_Info_Of (Cp_FIFO_Source).Kind = Hostkit.Fs.FIFO then
         Context.Initialize ("test", Two_Args ("-p", Cp_FIFO_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "test -p FIFO status");

         Context.Initialize ("test", Two_Args ("-S", Cp_FIFO_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -S excludes FIFO status");
      end if;

      if Hostkit.Fs.Special_File_Info_Of (Cp_Socket_Source).Kind = Hostkit.Fs.Socket then
         Context.Initialize ("test", Two_Args ("-S", Cp_Socket_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "test -S socket status");

         Context.Initialize ("test", Two_Args ("-p", Cp_Socket_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -p excludes socket status");
      end if;

      if Ada.Directories.Exists ("/dev/null")
        and then Hostkit.Fs.Special_File_Info_Of ("/dev/null").Kind = Hostkit.Fs.Character_Device
      then
         Context.Initialize ("test", Two_Args ("-c", "/dev/null"));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "test -c character device status");

         Context.Initialize ("test", Two_Args ("-b", "/dev/null"));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -b excludes character device status");
      end if;

      Context.Initialize ("test", Two_Args ("-t", "0"));
      Test_Contexts.Set_Standard_Input_Is_Terminal (Context, True);
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -t stdin status");

      Context.Initialize ("test", Two_Args ("-t", "1"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -t stdout status");

      Context.Initialize ("test", Two_Args ("-t", "2"));
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, True);
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -t stderr status");

      Context.Initialize ("test", Two_Args ("-t", "9"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -t unsupported fd status");

      Context.Initialize ("test", Three_Args ("42", "-eq", "42"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -eq status");

      Context.Initialize ("test", Three_Args ("-2", "-lt", "+3"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test signed -lt status");

      Context.Initialize ("test", Three_Args ("!", "-n", ""));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test negated unary status");

      Context.Initialize ("test", Four_Args ("!", "1", "=", "2"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test negated equality status");

      Context.Initialize ("test", Four_Args ("!", "2", "-gt", "1"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test negated numeric status");

      Context.Initialize ("test", Five_Args ("-n", "x", "-a", "-z", ""));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test and status");

      Context.Initialize ("test", Three_Args ("", "-o", "fallback"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test or status");

      Context.Initialize ("test", Five_Args ("", "-o", "", "-a", "x"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test and precedence status");

      Context.Initialize ("test", Six_Args ("!", "x", "-o", "", "-a", "y"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test negated compound status");

      Context.Initialize ("test", Three_Args ("(", "value", ")"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test parenthesized status");

      Context.Initialize ("test", Three_Args ("abc", "-eq", "0"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test invalid numeric comparison is false");

      Context.Initialize ("test", Two_Args ("(", "value"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects unbalanced opening parenthesis");

      Context.Initialize ("test", Two_Args ("value", ")"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects unbalanced closing parenthesis");

      Context.Initialize ("test", Two_Args ("value", "-a"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects dangling and operator");

      Context.Initialize ("test", Three_Args ("a", "-bad", "b"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects unknown binary operator");

      Write_File (Cksum_File, "abc");
      Context.Initialize ("cksum", One_Arg (Cksum_File));
      Posix_Tools.Commands.Cksum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), " 3 " & Cksum_File),
         "cksum prints checksum length and operand");

      Context.Initialize ("cksum", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Cksum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1219131554 3" & EOL,
         "cksum reads implicit standard input");

      Context.Initialize ("cksum", One_Arg ("--"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Cksum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1219131554 3" & EOL,
         "cksum treats a sole -- as end-of-options before implicit standard input");

      Context.Initialize ("sha256sum", One_Arg (Source));
      Posix_Tools.Commands.Sha256sum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "31f096ed11381d8885e6bb572b98782840325a88e582dc576a039b6564ca9c77  " & Source & EOL,
         "sha256sum prints known file digest and operand");

      Write_File
        (Cksum_File,
         "31f096ed11381d8885e6bb572b98782840325a88e582dc576a039b6564ca9c77  " & Source & EOL);
      Context.Initialize ("sha256sum", Two_Args ("-c", Cksum_File));
      Posix_Tools.Commands.Sha256sum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Source & ": OK" & EOL,
         "sha256sum verifies checksum files");

      Context.Initialize ("sha256sum", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Sha256sum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" & EOL,
         "sha256sum reads implicit standard input");

      Context.Initialize ("sha256sum", No_Args);
      Test_Contexts.Set_Standard_Input (Context, Large_Hash_Input);
      Posix_Tools.Commands.Sha256sum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "42e8bc96b8eec8c4e5d503483ba0cb843ce95243c8ca8575ffc69cd25d12c61c" & EOL,
         "sha256sum streams input larger than one chunk");

      Write_File (Cmp_First, "same" & EOL);
      Write_File (Cmp_Second, "same" & EOL);
      Context.Initialize ("cmp", Two_Args (Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "cmp accepts equal files quietly");

      Write_File (Cmp_Second, "sage" & EOL);
      Context.Initialize ("cmp", Two_Args (Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Output (Context), "differ"),
         "cmp reports the first difference");

      Write_File (Cmp_First, "abc");
      Write_File (Cmp_Second, "axd");
      Context.Initialize ("cmp", Three_Args ("-l", Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "2 142 170" & EOL & "3 143 144" & EOL,
         "cmp -l lists all differing byte values in octal");

      Context.Initialize ("cmp", Four_Args ("-l", "-s", Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "cmp -s suppresses cmp -l output");

      Context.Initialize ("cmp", Four_Args ("-s", "--", Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "cmp accepts -- after -s and stays silent");

      Write_File (Cmp_First, "ab" & EOL & "cd" & EOL);
      Write_File (Cmp_Second, "ab" & EOL & "cx" & EOL);
      Context.Initialize ("cmp", Two_Args (Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Output (Context), "byte 5, line 2"),
         "cmp reports the line containing the first differing byte");

      Write_File (Cmp_First, "short");
      Write_File (Cmp_Second, "shorter");
      Context.Initialize ("cmp", Two_Args (Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Output (Context), "EOF on " & Cmp_First),
         "cmp reports EOF on the shorter file");

      Write_File (Paste_First, "a" & EOL & "b" & EOL);
      Write_File (Paste_Second, "1" & EOL & "2" & EOL);
      Context.Initialize ("paste", Two_Args (Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & Character'Val (9) & "1" & EOL
           & "b" & Character'Val (9) & "2" & EOL,
         "paste merges lines with tabs");

      Context.Initialize ("paste", Three_Args ("--", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & Character'Val (9) & "1" & EOL
           & "b" & Character'Val (9) & "2" & EOL,
         "paste honors end-of-options before file operands");

      Context.Initialize ("paste", Four_Args ("-d", "|", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a|1" & EOL & "b|2" & EOL,
         "paste accepts a separate delimiter list");

      Context.Initialize ("paste", Three_Args ("-d,", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a,1" & EOL & "b,2" & EOL,
         "paste accepts an attached delimiter list");

      Context.Initialize ("paste", Three_Args ("-d\0", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a1" & EOL & "b2" & EOL,
         "paste delimiter list supports backslash-zero as an empty delimiter");

      Context.Initialize ("paste", Four_Args ("-d", "\n", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL & "1" & EOL & "b" & EOL & "2" & EOL,
         "paste delimiter list supports newline escape");

      Context.Initialize ("paste", Three_Args ("-s", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & Character'Val (9) & "b" & EOL
           & "1" & Character'Val (9) & "2" & EOL,
         "paste serial mode combines each file separately");

      Context.Initialize ("paste", One_Arg ("-d"));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-d'"),
         "paste rejects a missing delimiter list");

      Write_File (Cut_File, "abcd" & EOL & "wxyz" & EOL);
      Context.Initialize ("cut", Three_Args ("-b", "2-3", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "bc" & EOL & "xy" & EOL,
         "cut selects byte ranges");

      Context.Initialize ("cut", Three_Args ("-b", "1 4", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ad" & EOL & "wz" & EOL,
         "cut accepts blank-separated list entries");

      Context.Initialize ("cut", Four_Args ("-n", "-b", "1-2", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab" & EOL & "wx" & EOL,
         "cut accepts -n with byte mode");

      Context.Initialize ("cut", Three_Args ("-b", "999999999999999999999999999999", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "cut rejects overflowing list number");

      Context.Initialize ("cut", Three_Args ("-n", "-c", "1"));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "cut rejects -n outside byte mode");

      Context.Initialize ("cut", Five_Args ("-b", "1", "-c", "2", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "multiple list options"),
         "cut rejects multiple list options");

      Context.Initialize ("cut", Five_Args ("-b", "1", "-d", ",", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "invalid field option"),
         "cut rejects field delimiter option outside field mode");

      Context.Initialize ("cut", Three_Args ("-s", "-b", "1"));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "invalid field option"),
         "cut rejects field suppression option outside field mode");

      Write_File (Cut_File, "a,b,c" & EOL);
      Context.Initialize ("cut", Five_Args ("-f", "2", "-d", ",", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "b" & EOL,
         "cut selects delimited fields");

      Context.Initialize ("cut", Four_Args ("-f", "2", "-d,", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "b" & EOL,
         "cut accepts an attached delimiter option argument");

      Context.Initialize ("cut", Two_Args ("-f", "2"));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "cut reads standard input when only a list option is supplied");

      Context.Initialize ("cut", Three_Args ("-f", "2", "-d"));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-d'"),
         "cut rejects a missing delimiter argument");

      Write_File (Comm_First, "a" & EOL & "b" & EOL);
      Write_File (Comm_Second, "b" & EOL & "c" & EOL);
      Context.Initialize ("comm", Two_Args (Comm_First, Comm_Second));
      Posix_Tools.Commands.Comm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL
           & Character'Val (9) & Character'Val (9) & "b" & EOL
           & Character'Val (9) & "c" & EOL,
         "comm merges sorted files into three columns");

      Context.Initialize ("comm", Three_Args ("-12", Comm_First, Comm_Second));
      Posix_Tools.Commands.Comm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "b" & EOL,
         "comm suppression options leave only common lines");

      Context.Initialize ("comm", Three_Args ("--", Comm_First, Comm_Second));
      Posix_Tools.Commands.Comm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL
           & Character'Val (9) & Character'Val (9) & "b" & EOL
           & Character'Val (9) & "c" & EOL,
         "comm honors end-of-options before operands");

      Write_File (Od_File, "A");
      Context.Initialize ("od", One_Arg (Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), "0000000 000101")
         and then Contains (Test_Contexts.Output (Context), "0000001"),
         "od emits octal byte dump");

      Context.Initialize ("od", Two_Args ("-An", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = " 000101" & EOL,
         "od -An suppresses address output");

      Context.Initialize ("od", Two_Args ("-Ax", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 000101" & EOL & "0000001" & EOL,
         "od -Ax emits hexadecimal address output");

      Context.Initialize ("od", Three_Args ("-A", "d", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0 000101" & EOL & "1" & EOL,
         "od accepts a separate decimal address-base argument");

      Context.Initialize ("od", One_Arg ("-A"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-A'"),
         "od rejects a missing address-base argument");

      Context.Initialize ("od", Two_Args ("-A", "bad"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "od rejects an invalid address base");

      Write_File (Od_File, "ABCDEF");
      Context.Initialize ("od", Five_Args ("-j", "2", "-N", "3", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000002 042103 000105" & EOL & "0000005" & EOL,
         "od skips and limits input bytes");

      Context.Initialize ("od", Three_Args ("-j0x2", "-N03", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000002 042103 000105" & EOL & "0000005" & EOL,
         "od accepts attached hexadecimal skip and octal count");

      Context.Initialize ("od", Three_Args ("-N", "0", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000" & EOL,
         "od accepts a zero byte limit");

      Write_File (Od_File, String'(1 .. 512 => 'x') & "AB");
      Context.Initialize ("od", Two_Args ("-j1b", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0001000 041101" & EOL & "0001002" & EOL,
         "od supports block suffix skip arguments");

      Context.Initialize ("od", Two_Args ("-j1k", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "od rejects skips beyond input");

      Context.Initialize ("od", One_Arg ("-j"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-j'"),
         "od rejects a missing skip argument");

      Context.Initialize ("od", Two_Args ("-N", "0x"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "od rejects malformed count arguments");

      Write_File (Od_File, "ABCDEF");
      Context.Initialize ("od", Two_Args ("-tx1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 41 42 43 44 45 46" & EOL & "0000006" & EOL,
         "od supports attached hexadecimal byte type strings");

      Write_File (Od_File, String'(1 .. 32 => 'A'));
      Context.Initialize ("od", Two_Args ("-tx1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "0000000 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41" & EOL
           & "*" & EOL
           & "0000040" & EOL,
         "od suppresses duplicate output blocks by default");

      Context.Initialize ("od", Three_Args ("-v", "-tx1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "0000000 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41" & EOL
           & "0000020 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41" & EOL
           & "0000040" & EOL,
         "od -v emits duplicate output blocks");

      Write_File (Od_File, "ABCDEF");
      Context.Initialize ("od", Three_Args ("-t", "u1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 65 66 67 68 69 70" & EOL & "0000006" & EOL,
         "od supports separate unsigned byte type strings");

      Context.Initialize ("od", Two_Args ("-tx2", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 4241 4443 4645" & EOL & "0000006" & EOL,
         "od supports two-byte hexadecimal type strings");

      Context.Initialize ("od", Two_Args ("-td2", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 16961 17475 17989" & EOL & "0000006" & EOL,
         "od supports two-byte decimal type strings");

      Write_File (Od_File, Character'Val (255) & Character'Val (255));
      Context.Initialize ("od", Two_Args ("-td2", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 -1" & EOL & "0000002" & EOL,
         "od supports signed multi-byte type strings");

      Context.Initialize ("od", Two_Args ("-s", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 -1" & EOL & "0000002" & EOL,
         "od supports signed decimal shorthand");

      Context.Initialize ("od", Two_Args ("-d", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 65535" & EOL & "0000002" & EOL,
         "od supports unsigned decimal shorthand");

      Write_File (Od_File, Character'Val (0) & Character'Val (0) & Character'Val (128) & Character'Val (63));
      Context.Initialize ("od", Two_Args ("-tf4", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000  1.00000E+00" & EOL & "0000004" & EOL,
         "od supports single-precision floating type strings");

      Write_File
        (Od_File,
         Character'Val (0) & Character'Val (0) & Character'Val (0) & Character'Val (0)
         & Character'Val (0) & Character'Val (0) & Character'Val (240) & Character'Val (63));
      Context.Initialize ("od", Two_Args ("-tfD", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000  1.00000000000000E+00" & EOL & "0000010" & EOL,
         "od supports double-precision floating type strings");

      Write_File (Od_File, "A" & Character'Val (10) & Character'Val (0));
      Context.Initialize ("od", Two_Args ("-tc", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000   A  \\n  \\0" & EOL & "0000003" & EOL,
         "od supports character byte type strings");

      Context.Initialize ("od", Two_Args ("-ta", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000   A  nl nul" & EOL & "0000003" & EOL,
         "od supports named character type strings");

      Write_File (Od_File, "AB");
      Context.Initialize ("od", Five_Args ("-t", "x1", "-t", "c", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 41 42" & EOL & "   A   B" & EOL & "0000002" & EOL,
         "od supports multiple type-string output lines");

      Context.Initialize ("od", Two_Args ("-t", "f1"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "od rejects unsupported type strings");

      Context.Initialize ("od", Two_Args ("-t", "x999999999999999999999999999999"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "od rejects overflowing type sizes");

      Context.Initialize ("ls", One_Arg (Od_File));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Od_File & EOL,
         "ls prints file operands");

      Ada.Directories.Create_Directory (Ls_Dir);
      Write_File (Hostkit.Fs.Join (Ls_Dir, "visible"), "visible" & EOL);
      Write_File (Hostkit.Fs.Join (Ls_Dir, ".hidden"), "hidden" & EOL);
      Context.Initialize ("ls", One_Arg (Ls_Dir));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "visible" & EOL,
         "ls hides dot-prefixed entries by default");

      Context.Initialize ("ls", Two_Args ("-A", Ls_Dir));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ".hidden" & EOL & "visible" & EOL,
         "ls -A includes hidden entries other than dot and dot-dot");

      Ada.Directories.Create_Directory (Ls_Other_Dir);
      Write_File (Hostkit.Fs.Join (Ls_Other_Dir, "zeta"), "zeta" & EOL);
      Context.Initialize ("ls", Two_Args (Ls_Dir, Ls_Other_Dir));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Ls_Dir & ":" & EOL
           & "visible" & EOL & EOL
           & Ls_Other_Dir & ":" & EOL
           & "zeta" & EOL,
         "ls labels multiple directory operands");

      Write_File (Split_Input, "a" & EOL & "b" & EOL & "c" & EOL);
      Context.Initialize ("split", Four_Args ("-l", "2", Split_Input, Split_Prefix));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "split status");
      Context.Initialize ("cat", One_Arg (Split_Prefix & "aa"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL, "split first file");
      Context.Initialize ("cat", One_Arg (Split_Prefix & "ab"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "c" & EOL, "split second file");

      Context.Initialize ("split", Six_Args ("-a", "3", "-l", "1", Split_Input, Split_Long_Prefix));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "split -a status");
      Context.Initialize ("cat", One_Arg (Split_Long_Prefix & "aaa"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL, "split -a first file");
      Context.Initialize ("cat", One_Arg (Split_Long_Prefix & "aac"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "c" & EOL, "split -a third file");

      Context.Initialize ("split", One_Arg ("-a"));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-a'"),
         "split rejects a missing suffix length");

      Context.Initialize ("split", Two_Args ("-a", "0"));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "split rejects a zero suffix length");

      Remove_Any (Source);
      Remove_Any (Target);
      Remove_Any (Large_Source);
      Remove_Any (Large_Target);
      Remove_Any (Dash_Target);
      Remove_Any (Linked);
      Remove_Any (Link_Command_Target);
      Remove_Any (Symlinked);
      Remove_Any (Cp_Symlinked);
      Remove_Any (Link_Dir);
      Remove_Any (Moved);
      Remove_Any (Made);
      Remove_Any (Mkfifo_Target);
      Remove_Any (Symbolic_Mode_Dir);
      Remove_Any (Relative_Mode_Dir);
      Remove_Any (Remove_Dir);
      Remove_Any (Multi);
      Remove_Any (Other);
      Remove_Any (Tree);
      Remove_Any (Tree_Copy);
      Remove_Any (Sort_Out);
      Remove_Any (Empty);
      Remove_Any (Cp_Directory_Source);
      Remove_Any (Cp_Directory_Target);
      Remove_Any (Cp_FIFO_Source);
      Remove_Any (Cp_FIFO_Target);
      Remove_Any (Cp_Socket_Source);
      Remove_Any (Cp_Socket_Target);
      Remove_Any (Parent_Block);
      Remove_Any (Option_Dir);
      Remove_Any (Touched);
      Remove_Any (No_Create);
      Remove_Any (Tee_Out);
      Remove_Any (Chmod_Target);
      Remove_Any (Cksum_File);
      Remove_Any (Cmp_First);
      Remove_Any (Cmp_Second);
      Remove_Any (Paste_First);
      Remove_Any (Paste_Second);
      Remove_Any (Cut_File);
      Remove_Any (Comm_First);
      Remove_Any (Comm_Second);
      Remove_Any (Od_File);
      Remove_Any (Ls_Dir);
      Remove_Any (Ls_Other_Dir);
      Remove_Any (Split_Input);
      Remove_Any (Split_Prefix & "aa");
      Remove_Any (Split_Prefix & "ab");
      Remove_Any (Split_Long_Prefix & "aaa");
      Remove_Any (Split_Long_Prefix & "aab");
      Remove_Any (Split_Long_Prefix & "aac");
      Ada.Directories.Create_Path (Option_Dir);
      Write_File (Hostkit.Fs.Join (Option_Dir, "-c"), "x" & EOL);
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "x" & EOL);
   end Test_Command_Surface_Smoke;

end Command_Tests.Surface_Smoke;
