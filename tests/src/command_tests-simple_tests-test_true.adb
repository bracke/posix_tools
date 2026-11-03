separate (Command_Tests.Simple_Tests)

   procedure Test_True (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("true", One_Arg ("ignored"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "true output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true status");
   end Test_True;
