separate (Command_Tests.Head_Tests)

   procedure Test_Head_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("head", Three_Args ("-n", "3", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Test_Contexts.Set_Output_Failure_After (Context, 2);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "head stops after failed write");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "head output failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "head output failure status");
   end Test_Head_Output_Failure;
