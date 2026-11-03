separate (Command_Tests.Simple_Tests)

   procedure Test_Basename_Edge_Cases (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("basename", One_Arg (""));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "" & LF, "basename command empty");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename empty status");

      Context.Initialize ("basename", One_Arg ("///"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/" & LF, "basename command root");

      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", "file.txt"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file.txt" & LF,
         "basename suffix equal full name");

      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", ".bin"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file.txt" & LF,
         "basename suffix absent");

      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", ""));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file.txt" & LF,
         "basename empty suffix");

      Context.Initialize ("basename", One_Arg ("a//b///"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & LF,
         "basename trailing repeated slash");

      Context.Initialize
        ("basename",
         Two_Args
           ("dir/" & Character'Val (16#C3#) & Character'Val (16#A6#) & ".txt",
            ".txt"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#C3#) & Character'Val (16#A6#) & LF,
         "basename non-ASCII suffix");

      Context.Initialize ("basename", One_Arg ("a\b"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a\b" & LF, "basename command backslash");
   end Test_Basename_Edge_Cases;
