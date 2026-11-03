separate (Command_Tests.Root_Tests)

   procedure Test_Root_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Output_Failure_After (Context, 5);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "Usage", "root partial output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "root output failure status");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "root output failure diagnostic");
   end Test_Root_Output_Failure;
