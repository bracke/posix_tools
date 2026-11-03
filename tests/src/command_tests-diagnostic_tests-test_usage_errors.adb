separate (Command_Tests.Diagnostic_Tests)

   procedure Test_Usage_Errors (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      ESC     : constant Character := Character'Val (16#1B#);
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "dirname extra status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "dirname: extra operand 'second'" & LF,
         "dirname extra diagnostic");

      Context.Initialize ("dirname", Two_Args ("first", "bad" & LF & ESC & "[31m"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "dirname: extra operand 'bad\x0A\x1B[31m'" & LF,
         "usage diagnostic escapes control characters");

      Context.Initialize ("cat", One_Arg (Fixture_Path ("missing" & LF & ESC & "[31m")));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "cat: '" & Fixture_Path ("missing\x0A\x1B[31m") & "': cannot read file" & LF,
         "subject diagnostic escapes control characters");

      Context.Initialize ("posix-tools", One_Arg ("unknown"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "root unknown status");

      --  An unknown option is quoted and escaped like every other operand a
      --  usage diagnostic names, whichever command reports it.
      Context.Initialize ("seq", Two_Args ("-" & ESC & "[31m", "3"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "seq unknown option status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "seq: unknown option '-\x1B'" & LF,
         "unknown option diagnostic escapes control characters");

      Context.Initialize ("nl", One_Arg ("-q"));
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Error_Output (Context) = "nl: unknown option '-q'" & LF,
         "nl unknown option diagnostic is quoted");

      Context.Initialize ("touch", Three_Args ("-t", "bad" & LF, "file"));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Error_Output (Context) = "touch: invalid timestamp 'bad\x0A'" & LF,
         "touch invalid timestamp diagnostic escapes its operand");

      Context.Initialize ("xargs", Two_Args ("-n", "0"));
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Error_Output (Context) = "xargs: invalid argument count '0'" & LF,
         "xargs zero argument count diagnostic");

      Context.Initialize ("dd", One_Arg ("skip=" & ESC));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Error_Output (Context) = "dd: invalid skip 'skip=\x1B'" & LF,
         "dd invalid skip diagnostic escapes its operand");
   end Test_Usage_Errors;
