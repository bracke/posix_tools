separate (Command_Tests.Locale_Tests)

   procedure Test_Pwd_Context_Fallbacks (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      Physical : constant String := "/physical/fallback";
      Logical  : constant String := "/logical/default";
      LF       : constant Character := Character'Val (10);
   begin
      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", Logical);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Logical & LF, "pwd default logical output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd default logical status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", Logical);
      Test_Contexts.Set_Logical_Pwd_Matches_Current_Directory (Context, False);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd stale PWD fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd stale PWD status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd empty PWD fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd empty PWD status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "relative/path");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd relative PWD fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd relative PWD status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/./test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd dot component fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd dot component status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/../test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd dot-dot component fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd dot-dot component status");

      Context.Initialize ("pwd", Two_Args ("-P", "-L"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", Logical);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Logical & LF, "pwd -P -L last option output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -P -L status");
   end Test_Pwd_Context_Fallbacks;
