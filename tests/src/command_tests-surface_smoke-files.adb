with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Command_Tests.Surface_Smoke.Fixtures;
with Command_Tests.Surface_Smoke.Helpers;
with Hostkit.Fs;
with Hostkit.Metadata;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Chgrp;
with Posix_Tools.Commands.Chmod;
with Posix_Tools.Commands.Chown;
with Posix_Tools.Commands.Cp;
with Posix_Tools.Commands.Link;
with Posix_Tools.Commands.Ln;
with Posix_Tools.Commands.Mkdir;
with Posix_Tools.Commands.Mkfifo;
with Posix_Tools.Commands.Mv;
with Posix_Tools.Commands.Readlink;
with Posix_Tools.Commands.Realpath;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rm;
with Posix_Tools.Commands.Rmdir;
with Posix_Tools.Commands.Stat;
with Posix_Tools.Commands.Tee;
with Posix_Tools.Commands.Touch;
with Posix_Tools.Exit_Status;
with Test_Contexts;

package body Command_Tests.Surface_Smoke.Files is
   use type Ada.Directories.File_Size;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Fs.Special_File_Kind;
   use type Ada.Calendar.Time;
   use type Posix_Tools.Exit_Status.Code;
   use Ada.Strings.Unbounded;
   use Command_Tests.Surface_Smoke.Fixtures;
   use Command_Tests.Surface_Smoke.Helpers;

   --  Windows keeps a link's target in its own separators, the only ones it
   --  follows a link by; the target is the same path.
   function Same_Path (Left, Right : String) return Boolean;

   function Same_Path (Left, Right : String) return Boolean is
      Slashes : constant Ada.Strings.Maps.Character_Mapping := Ada.Strings.Maps.To_Mapping ("\", "/");
   begin
      return Ada.Strings.Fixed.Translate (Left, Slashes) = Ada.Strings.Fixed.Translate (Right, Slashes);
   end Same_Path;

   procedure Test_Chmod (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
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
      --  A host whose programs carry a suffix (Windows) reports execute only
      --  for files it would run, and this one is a .txt.
      Assert_Mode_When_Available
        (Chmod_Target,
         (if Hostkit.Fs.Executable_Suffix = "" then 8#555# else 8#444#),
         "chmod applies symbolic copy mode");

      --  POSIX's grammar lets an op stand without perms: "u+" adds nothing.
      Context.Initialize ("chmod", Two_Args ("u+", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success, "chmod accepts an op without perms");

      Context.Initialize ("chmod", Two_Args ("u+q", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "chmod rejects an unknown perm");
   end Test_Chmod;

   procedure Test_Chown_Chgrp (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Chmod_Target, "mode-data");
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
   end Test_Chown_Chgrp;

   procedure Test_Cp (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
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
               and then Same_Path (To_String (Target_Text), Source),
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
         --  Against the time set above, not the source's now: reading the
         --  source to copy it may move its access time (macOS does).
         declare
            Target_Access_Available : Boolean;
            Source_Access : constant Ada.Calendar.Time :=
              Ada.Calendar.Formatting.Time_Of (1970, 1, 1, 0.0, Time_Zone => 0) + Duration (1_612_325_106);
            Target_Access : constant Ada.Calendar.Time :=
              Hostkit.Metadata.File_Access_Time (Target, Target_Access_Available);
         begin
            if Target_Access_Available then
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
         --  Without -R a special file is read for what it holds, as POSIX
         --  has it, and its copy is a regular file.
         Remove_Any (Target);
         Context.Initialize ("cp", Two_Args ("/dev/null", Target));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Ada.Directories.Kind (Target) = Ada.Directories.Ordinary_File
            and then Ada.Directories.Size (Target) = 0,
            "cp copies a special file's contents without -R");
      end if;

      if Hostkit.Fs.Create_FIFO (Cp_FIFO_Source, 8#600#) then
         Context.Initialize ("cp", Three_Args ("-R", Cp_FIFO_Source, Cp_FIFO_Target));
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
         Context.Initialize ("cp", Three_Args ("-R", Cp_Socket_Source, Cp_Socket_Target));
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
   end Test_Cp;

   procedure Test_Cp_Multiple_Sources (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
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
   end Test_Cp_Multiple_Sources;

   procedure Test_Link (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
      Context.Initialize ("link", Two_Args (Source, Link_Command_Target));
      Posix_Tools.Commands.Link.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Hostkit.Metadata.Same_File (Source, Link_Command_Target),
         "link creates hard link");
   end Test_Link;

   procedure Test_Ln (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
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
               and then Same_Path (To_String (Target_Text), Source),
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
   end Test_Ln;

   procedure Test_Mkdir (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
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
   end Test_Mkdir;

   procedure Test_Mkfifo (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
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
   end Test_Mkfifo;

   procedure Test_Mv (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Linked, "move-data");
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
   end Test_Mv;

   procedure Test_Mv_End_Of_Options (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
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
   end Test_Mv_End_Of_Options;

   procedure Test_Mv_Multiple_Sources (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
      Ada.Directories.Create_Directory (Made);
      Ada.Directories.Create_Directory (Multi);
      Write_File (Multi & "/command-source.txt", "copy-data");
      Write_File (Multi & "/command-other.txt", "other-data");
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
   end Test_Mv_Multiple_Sources;

   procedure Test_Option_Operands (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
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
   end Test_Option_Operands;

   procedure Test_Readlink (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
      Create_Symbolic_Link_If_Supported (Source, Symlinked);
      if Hostkit.Fs.Is_Link (Symlinked) then
         Context.Initialize ("readlink", One_Arg (Symlinked));
         Posix_Tools.Commands.Readlink.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Same_Path (Test_Contexts.Output (Context), Source & EOL),
            "readlink writes symbolic link target");
      end if;
   end Test_Readlink;

   procedure Test_Realpath (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
      Context.Initialize ("realpath", One_Arg (Source));
      Posix_Tools.Commands.Realpath.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Hostkit.Fs.Real_Path (Source) & EOL,
         "realpath writes resolved path");
   end Test_Realpath;

   procedure Test_Rm (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
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
   end Test_Rm;

   procedure Test_Rm_Directory (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Ada.Directories.Create_Directory (Remove_Dir);
      Context.Initialize ("rm", Two_Args ("-d", Remove_Dir));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Remove_Dir),
         "rm -d removed empty directory");
   end Test_Rm_Directory;

   procedure Test_Rm_Verbose (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
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
   end Test_Rm_Verbose;

   procedure Test_Rmdir (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
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
   end Test_Rmdir;

   procedure Test_Stat (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
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
   end Test_Stat;

end Command_Tests.Surface_Smoke.Files;
