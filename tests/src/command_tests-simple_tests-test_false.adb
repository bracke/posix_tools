separate (Command_Tests.Simple_Tests)

   procedure Test_False (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("false", One_Arg ("ignored"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "false output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "false status");
   end Test_False;
