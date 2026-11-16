separate (Command_Tests.Surface_Smoke.Files)
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
