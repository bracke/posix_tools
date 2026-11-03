separate (Command_Tests.Simple_Tests)

   procedure Test_Basename (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", ".txt"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "file" & Character'Val (10), "basename output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename status");
   end Test_Basename;
