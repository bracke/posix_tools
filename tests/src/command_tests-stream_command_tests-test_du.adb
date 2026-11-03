separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Du (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Work_Root    : constant String := Work_Path ("du");
      Small_Path   : constant String := Hostkit.Fs.Join (Work_Root, "du-small.bin");
      Large_Path   : constant String := Hostkit.Fs.Join (Work_Root, "du-large.bin");
      Dir_Path     : constant String := Hostkit.Fs.Join (Work_Root, "du-dir");
      Child_Path   : constant String := Hostkit.Fs.Join (Dir_Path, "child.bin");
      Missing_Path : constant String := Hostkit.Fs.Join (Work_Root, "du-missing.bin");
      LF           : constant Character := Character'Val (10);
      HT           : constant Character := Character'Val (9);

   begin
      Delete_If_Exists (Work_Root);
      Ada.Directories.Create_Path (Work_Root);

      Write_File (Small_Path, "x");
      Write_File (Large_Path, String'(1 .. 1025 => 'x'));
      Ada.Directories.Create_Directory (Dir_Path);
      Write_File (Child_Path, "child");

      Context.Initialize ("du", One_Arg (Small_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1" & HT & Small_Path & LF,
         "du reports top-level regular file");

      Context.Initialize ("du", Two_Args ("-k", Large_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "2" & HT & Large_Path & LF,
         "du -k reports KiB-rounded units");

      Context.Initialize ("du", Two_Args ("-a", Dir_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), HT & Child_Path & LF)
         and then Contains (Test_Contexts.Output (Context), HT & Dir_Path & LF),
         "du -a reports child and directory paths");

      Context.Initialize ("du", Two_Args ("-s", Dir_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), HT & Dir_Path & LF)
         and then not Contains (Test_Contexts.Output (Context), HT & Child_Path & LF),
         "du -s reports only the top-level directory summary");

      Context.Initialize ("du", Two_Args (Dir_Path, Dir_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Occurrences (Test_Contexts.Output (Context), HT & Dir_Path & LF) = 2,
         "du resets cycle tracking for each top-level operand");

      Context.Initialize ("du", One_Arg (Missing_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "du reports missing path as operational failure");

      Context.Initialize ("du", One_Arg ("-z"));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "du rejects unknown options");

      Delete_If_Exists (Work_Root);
   end Test_Du;
