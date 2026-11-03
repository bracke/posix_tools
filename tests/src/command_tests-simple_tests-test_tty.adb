separate (Command_Tests.Simple_Tests)

   procedure Test_Tty (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("tty", No_Args);
      Test_Contexts.Set_Standard_Input_Is_Terminal (Context, True);
      Posix_Tools.Commands.Tty.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "/dev/test-tty" & Character'Val (10),
         "tty prints the terminal name");

      Context.Initialize ("tty", No_Args);
      Test_Contexts.Set_Standard_Input_Is_Terminal (Context, False);
      Posix_Tools.Commands.Tty.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "not a tty" & Character'Val (10),
         "tty reports non-terminal standard input");

      Context.Initialize ("tty", One_Arg ("-s"));
      Test_Contexts.Set_Standard_Input_Is_Terminal (Context, False);
      Posix_Tools.Commands.Tty.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "tty -s suppresses output");

      Context.Initialize ("tty", No_Args);
      Test_Contexts.Set_Standard_Input_Is_Terminal (Context, True);
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Tty.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Tty_Error, "tty exits above 1 when its output fails");

      Context.Initialize ("tty", One_Arg ("-x"));
      Posix_Tools.Commands.Tty.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tty rejects unknown options");
   end Test_Tty;
