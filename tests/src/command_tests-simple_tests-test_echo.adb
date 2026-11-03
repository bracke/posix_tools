separate (Command_Tests.Simple_Tests)

   procedure Test_Echo (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("echo", Three_Args ("", "-n", "x"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = " -n x" & Character'Val (10), "echo output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo status");
   end Test_Echo;
