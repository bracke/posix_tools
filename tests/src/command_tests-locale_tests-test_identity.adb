separate (Command_Tests.Locale_Tests)

   procedure Test_Identity (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;

      function Expected (Command : String) return String is
      begin
         return
           "schema=1" & Character'Val (10)
           & "project=posix-tools" & Character'Val (10)
           & "command=" & Command & Character'Val (10)
           & "version=" & Posix_Tools.Version.Version_String & Character'Val (10);
      end Expected;
   begin
      Context.Initialize ("basename", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("basename"), "basename identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename identity status");

      Context.Initialize ("cat", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("cat"), "cat identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat identity status");

      Context.Initialize ("dirname", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("dirname"), "dirname identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname identity status");

      Context.Initialize ("echo", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("echo"), "echo identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo identity status");

      Context.Initialize ("false", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("false"), "false identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "false identity status");

      Context.Initialize ("head", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("head"), "head identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head identity status");

      Context.Initialize ("pwd", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("pwd"), "pwd identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd identity status");

      Context.Initialize ("tail", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("tail"), "tail identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail identity status");

      Context.Initialize ("true", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("true"), "true identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true identity status");

      Context.Initialize ("wc", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("wc"), "wc identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc identity status");
   end Test_Identity;
