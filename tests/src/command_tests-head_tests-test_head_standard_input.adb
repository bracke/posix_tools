separate (Command_Tests.Head_Tests)

   procedure Test_Head_Standard_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("head", Three_Args ("-n", "2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "head stdin output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head stdin status");

      Context.Initialize ("head", Three_Args ("-c", "3", "-"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "head stdin byte output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head stdin byte status");

      Context.Initialize ("head", Two_Args ("-c0", "-"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "head zero byte output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head zero byte status");

      Context.Initialize ("head", Five_Args ("-c", "2", "-n", "1", "-"));
      Test_Contexts.Set_Standard_Input (Context, "abc" & LF & "def" & LF);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc" & LF, "head last count option wins");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head last count status");

      Context.Initialize ("head", Three_Args ("-n", "1", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "head stdin avoids extra read");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "head stdin avoids extra read diagnostic");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head stdin avoids extra read status");

      Context.Initialize ("head", Four_Args ("-n", "1", "-", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "==> - <==" & LF
           & "a" & LF
           & LF
           & "==> - <==" & LF,
         "head repeated stdin is not rewound");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head repeated stdin status");

      Context.Initialize ("head", Three_Args ("-n", "1", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "head stdin read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "head: 'standard input': cannot read file" & LF,
         "head stdin read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "head stdin read failure status");
   end Test_Head_Standard_Input;
