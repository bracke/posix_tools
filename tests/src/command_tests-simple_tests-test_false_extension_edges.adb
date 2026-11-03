separate (Command_Tests.Simple_Tests)

   procedure Test_False_Extension_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("false", One_Arg ("--version"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "false (posix-tools) " & Posix_Tools.Version.Version_String & LF,
         "false sole version");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "false version status");

      Context.Initialize ("false", Two_Args ("--version", "ignored"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "false non-sole version ignored");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "false non-sole version status");

      Context.Initialize ("false", Two_Args ("--posix-tools-identify", "ignored"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "false non-sole identity ignored");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "false non-sole identity status");
   end Test_False_Extension_Edges;
