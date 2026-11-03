separate (Command_Tests.Simple_Tests)

   procedure Test_True_Extension_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("true", One_Arg ("--help"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: true [OPTION]... [OPERAND]..." & LF
           & "Ada implementation in the posix-tools package." & LF
           & "Options:" & LF
           & "  --help     display this help and exit" & LF
           & "  --version  display version information and exit" & LF,
         "true sole help");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true help status");

      Context.Initialize ("true", Two_Args ("--help", "ignored"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "true non-sole help ignored");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true non-sole help status");

      Context.Initialize ("true", Two_Args ("--posix-tools-identify", "ignored"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "true non-sole identity ignored");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true non-sole identity status");
   end Test_True_Extension_Edges;
