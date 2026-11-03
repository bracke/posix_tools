separate (Command_Tests.Option_Behavior_Tests)

   procedure Test_End_Of_Options (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-end-of-options.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("basename", Two_Args ("--", "--help"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "--help" & LF, "basename -- operand output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename -- operand status");

      Context.Initialize ("dirname", Two_Args ("--", "a/b"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "dirname -- operand output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname -- operand status");

      Write_File (Path, "data");
      Context.Initialize ("cat", Two_Args ("--", Path));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "data", "cat skips end-of-options marker");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat -- file status");

      Context.Initialize ("pwd", One_Arg ("--"));
      Test_Contexts.Set_Physical_Current_Directory (Context, "/physical");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/physical" & LF, "pwd -- output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -- status");

      Context.Initialize ("pwd", Two_Args ("--", "extra"));
      Test_Contexts.Set_Physical_Current_Directory (Context, "/physical");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "pwd -- extra status");

      Write_File (Path, "a" & LF & "b" & LF);
      Context.Initialize ("head", Two_Args ("--", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "head skips leading --");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head leading -- status");

      Context.Initialize ("head", Four_Args ("-n", "1", "--", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "head skips -- after count");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head -- status");

      Context.Initialize ("tail", Two_Args ("--", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "tail skips leading --");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail leading -- status");

      Context.Initialize ("tail", Four_Args ("-n", "1", "--", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF, "tail skips -- after count");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -- status");

      Context.Initialize ("wc", Two_Args ("--", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "2 2 4 " & Path & LF, "wc skips leading --");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc leading -- status");

      Context.Initialize ("wc", Three_Args ("-c", "--", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "4 " & Path & LF, "wc skips -- after option");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -- status");
   end Test_End_Of_Options;
