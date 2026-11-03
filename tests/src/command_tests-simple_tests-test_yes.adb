separate (Command_Tests.Simple_Tests)

   procedure Test_Yes (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("yes", No_Args);
      Test_Contexts.Set_Output_Failure_After (Context, 6);
      Posix_Tools.Commands.Yes.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "y" & LF & "y" & LF & "y" & LF,
         "yes repeats default y until output failure");

      Context.Initialize ("yes", Two_Args ("ok", "now"));
      Test_Contexts.Set_Output_Failure_After (Context, 14);
      Posix_Tools.Commands.Yes.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "ok now" & LF & "ok now" & LF,
         "yes repeats joined operands until output failure");
   end Test_Yes;
