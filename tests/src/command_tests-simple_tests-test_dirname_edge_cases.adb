separate (Command_Tests.Simple_Tests)

   procedure Test_Dirname_Edge_Cases (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("dirname", One_Arg (""));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "." & LF, "dirname command empty");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname empty status");

      Context.Initialize ("dirname", One_Arg ("///"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/" & LF, "dirname command root");

      Context.Initialize ("dirname", One_Arg ("a//b"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "dirname repeated separator");

      Context.Initialize ("dirname", One_Arg ("/tmp/file"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/tmp" & LF, "dirname absolute path");

      Context.Initialize ("dirname", One_Arg ("a/b/"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "dirname trailing slash");

      Context.Initialize ("dirname", One_Arg ("file"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "." & LF, "dirname no slash");

      Context.Initialize ("dirname", One_Arg ("//tmp"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/" & LF, "dirname two leading slash");

      Context.Initialize ("dirname", One_Arg ("//a/b/"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/a" & LF, "dirname nested two leading slash");

      Context.Initialize ("dirname", One_Arg ("a\b"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "." & LF, "dirname command backslash");
   end Test_Dirname_Edge_Cases;
