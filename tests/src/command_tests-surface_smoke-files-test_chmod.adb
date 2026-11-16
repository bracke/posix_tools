separate (Command_Tests.Surface_Smoke.Files)
procedure Test_Chmod (T : in out Surface_Fixture) is
   pragma Unreferenced (T);
   Context        : Test_Contexts.Capturing_Context;
   Result         : Posix_Tools.Commands.Results.Result;
   Physical_Root  : constant String := Work_Path ("command-chmod-physical-root");
   Outside        : constant String := Work_Path ("command-chmod-outside");
   Outside_File   : constant String := Outside & "/file";
   Linked_Outside : constant String := Physical_Root & "/linked-outside";
begin
   if Posix_Tools.Host_Adapters.Path_Separators.Directory_Separator = '/' then
      AUnit.Assertions.Assert
        (Posix_Tools.Commands.Helpers.Relative_Beneath ("/", "/child") = "child",
         "a POSIX root rebases its child");
      AUnit.Assertions.Assert
        (Posix_Tools.Commands.Helpers.Relative_Beneath ("root\", "root\/child") = "child",
         "a POSIX backslash remains part of a directory name");
      AUnit.Assertions.Assert
        (Posix_Tools.Commands.Helpers.Relative_Beneath
           ("root//", "root//child") = "child",
         "repeated POSIX trailing separators stay at the root boundary");
      AUnit.Assertions.Assert
        (Posix_Tools.Commands.Helpers.Relative_Beneath
           ("///", "///child") = "child",
         "a repeated POSIX root rebases its child");
   else
      AUnit.Assertions.Assert
        (Posix_Tools.Commands.Helpers.Relative_Beneath ("C:\", "C:\child") = "child",
         "a drive root rebases its child");
      AUnit.Assertions.Assert
        (Posix_Tools.Commands.Helpers.Relative_Beneath ("C:/", "C:/child") = "child",
         "a drive root written with slashes rebases its child");
      AUnit.Assertions.Assert
        (Posix_Tools.Commands.Helpers.Relative_Beneath
           ("C:\\", "C:\\child") = "child",
         "a drive root with repeated trailing separators rebases its child");
   end if;

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

   Remove_Any (Linked_Outside);
   Remove_Any (Physical_Root);
   Remove_Any (Outside);
   Ada.Directories.Create_Directory (Physical_Root);
   Ada.Directories.Create_Directory (Outside);
   Write_File (Outside_File, "outside");
   declare
      Mode_Set : constant Boolean :=
        Hostkit.Metadata.Set_Permissions (Outside_File, 8#644#);
      pragma Unreferenced (Mode_Set);
   begin
      null;
   end;
   Create_Symbolic_Link_If_Supported (Outside, Linked_Outside);
   if Hostkit.Fs.Is_Link (Linked_Outside) then
      AUnit.Assertions.Assert
        (not Posix_Tools.Host_Adapters.File_System.Set_Permissions_No_Follow
           (Linked_Outside & "/file", 8#700#,
            Physical_Root, "linked-outside/file"),
         "a beneath update refuses a symbolic-link path component");
      Context.Initialize
        ("chmod", Three_Args ("-R", "700", Physical_Root));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "recursive chmod with a directory link succeeds physically");
      Assert_Mode_When_Available
        (Outside_File, 8#644#,
         "recursive chmod does not escape through a directory link");

      Write_File (Physical_Root & "/inside", "inside");
      Context.Initialize
        ("chmod", Three_Args ("-R", "700", Physical_Root & "/"));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "recursive chmod accepts a root with a trailing separator");
      Assert_Mode_When_Available
        (Physical_Root & "/inside", 8#700#,
         "recursive chmod updates children below a trailing separator");

      declare
         Reset : constant Boolean :=
           Hostkit.Metadata.Set_Permissions
             (Physical_Root & "/inside", 8#600#);
         pragma Unreferenced (Reset);
      begin
         null;
      end;
      Context.Initialize
        ("chmod", Three_Args ("-R", "700", Physical_Root & "//"));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "recursive chmod accepts repeated trailing separators");
      Assert_Mode_When_Available
        (Physical_Root & "/inside", 8#700#,
         "recursive chmod updates children below repeated separators");
   else
      Test_Support.Skip_Without_Links ("recursive chmod physical traversal");
   end if;
   Remove_Any (Linked_Outside);
   Remove_Any (Physical_Root);
   Remove_Any (Outside);
end Test_Chmod;
