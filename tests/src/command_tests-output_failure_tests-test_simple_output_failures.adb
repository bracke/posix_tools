separate (Command_Tests.Output_Failure_Tests)

   procedure Test_Simple_Output_Failures (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("basename", One_Arg ("abc"));
      Test_Contexts.Set_Output_Failure_After (Context, 1);
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a", "basename partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "basename output status");

      Context.Initialize ("dirname", One_Arg ("a/b"));
      Test_Contexts.Set_Output_Failure_After (Context, 1);
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a", "dirname partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "dirname output status");

      Context.Initialize ("echo", Two_Args ("ab", "cd"));
      Test_Contexts.Set_Output_Failure_After (Context, 2);
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "echo partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "echo output status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, "/physical");
      Test_Contexts.Set_Output_Failure_After (Context, 3);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/ph", "pwd partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "pwd output status");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "simple output failure diagnostic");
   end Test_Simple_Output_Failures;
