separate (Command_Tests.Xargs_Tests)

   procedure Test_Xargs_Continues_After_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("xargs", Three_Args ("-t", "-n1", "false"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Xargs_Utility_Failed
         and then Test_Contexts.Error_Output (Context) = "false a" & LF & "false b" & LF,
         "xargs runs every invocation after one exits 1-125 and then exits 123");

      Context.Initialize ("xargs", Three_Args ("-t", "-n1", "xargs-status-255"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Xargs_Utility_Requested_Stop
         and then Test_Contexts.Error_Output (Context)
           = "xargs-status-255 a" & LF & "xargs: 'xargs-status-255': command exited with status 255" & LF,
         "xargs stops after an invocation exits 255");

      Context.Initialize ("xargs", One_Arg ("xargs-signal-9"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Internal_Failure
         and then Test_Contexts.Error_Output (Context)
           = "xargs: 'xargs-signal-9': command terminated by a signal" & LF,
         "xargs stops and exits 125 when a signal ends an invocation");

      Context.Initialize ("xargs", One_Arg ("missing-utility"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Not_Found
         and then Test_Contexts.Error_Output (Context) = "xargs: 'missing-utility': command not found" & LF,
         "xargs reports a utility it cannot find");
   end Test_Xargs_Continues_After_Failure;
