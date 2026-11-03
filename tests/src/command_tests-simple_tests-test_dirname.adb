separate (Command_Tests.Simple_Tests)

   procedure Test_Dirname (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("dirname", One_Arg ("/tmp/file"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/tmp" & Character'Val (10), "dirname output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname status");
   end Test_Dirname;
