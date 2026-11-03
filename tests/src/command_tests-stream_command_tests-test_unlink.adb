separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Unlink (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("unlink-target.txt");
      Dash_Path : constant String := Fixture_Path ("-");

   begin
      Delete_If_Exists (Path);
      Delete_If_Exists (Dash_Path);
      Write_File (Path, "x");

      Context.Initialize ("unlink", One_Arg (Path));
      Posix_Tools.Commands.Unlink.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Path)
         and then Test_Contexts.Output (Context) = "",
         "unlink removes one file without output");

      Write_File (Dash_Path, "x");
      Context.Initialize ("unlink", Two_Args ("--", Dash_Path));
      Posix_Tools.Commands.Unlink.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Dash_Path),
         "unlink accepts end-of-options before operand");

      Context.Initialize ("unlink", No_Args);
      Posix_Tools.Commands.Unlink.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "unlink rejects missing operand");

      Context.Initialize ("unlink", Two_Args ("a", "b"));
      Posix_Tools.Commands.Unlink.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "unlink rejects extra operands");

      Context.Initialize ("unlink", One_Arg (Path));
      Posix_Tools.Commands.Unlink.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "unlink reports missing path");
   end Test_Unlink;
