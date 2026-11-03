separate (Command_Tests.Simple_Tests)

   procedure Test_Echo_Data_Edge_Cases (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("echo", Three_Args ("--", "a\b", "-n"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-- a\b -n" & LF,
         "echo treats -- backslash and -n as data");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo data edge status");

      Context.Initialize ("echo", Three_Args ("--help", "", "value"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "--help  value" & LF,
         "echo non-sole help preserves empty operand");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo non-sole help status");
   end Test_Echo_Data_Edge_Cases;
