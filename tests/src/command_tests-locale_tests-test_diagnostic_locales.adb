separate (Command_Tests.Locale_Tests)

   procedure Test_Diagnostic_Locales (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
      Missing : constant String := Fixture_Path ("missing-da-file.txt");
   begin
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "Danish diagnostic status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "dirname: ekstra operand 'second'" & LF,
         "Danish extra operand diagnostic");
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "Danish diagnostic stdout");

      Context.Initialize ("head", One_Arg ("-n"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "Danish missing option argument status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "head: mangler argument til valgmulighed '-n'" & LF,
         "Danish missing option argument diagnostic");

      Context.Initialize ("wc", One_Arg ("-z"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "Danish unknown option status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: ukendt valgmulighed '-z'" & LF,
         "Danish unknown option diagnostic");

      Context.Initialize ("head", One_Arg ("-nabc"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "Danish invalid line count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "head: ugyldigt linjeantal 'abc'" & LF,
         "Danish invalid line count diagnostic");

      --  Standard input is named in the messages locale too.
      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "cat: 'standardinput': "),
         "Danish standard input diagnostic names standard input in Danish");

      Context.Initialize ("cat", One_Arg (Missing));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "Danish read failure status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "cat: '" & Missing & "': kan ikke læse fil" & LF,
         "Danish read failure diagnostic");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Physical_Current_Directory (Context, "__raise_current_directory__");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "Danish pwd failure status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "pwd: kan ikke bestemme aktuel mappe" & LF,
         "Danish pwd failure diagnostic");

      Context.Initialize ("tail", Two_Args ("-c", "2147483648"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "Danish count too large status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: antal er for stort" & LF,
         "Danish count too large diagnostic");

      Context.Initialize ("wc", One_Arg ("-z"));
      Test_Contexts.Set_Locale (Context, "es");
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "Spanish unknown option status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: opcion desconocida '-z'" & LF,
         "Spanish unknown option diagnostic");

      Context.Initialize ("seq", Two_Args ("-q", "3"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Error_Output (Context) = "seq: ukendt valgmulighed '-q'" & LF,
         "Danish seq unknown option diagnostic");

      Context.Initialize ("expr", Two_Args ("(", "1"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Expr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Error_Output (Context) = "expr: mangler ')' i udtrykket" & LF,
         "Danish expr missing parenthesis diagnostic");

      Context.Initialize ("cut", Two_Args ("-b1", "-c1"));
      Test_Contexts.Set_Locale (Context, "es");
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Error_Output (Context) = "cut: varias opciones de lista" & LF,
         "Spanish cut multiple list options diagnostic");

      Context.Initialize ("touch", Three_Args ("-d", "nonsense", "file"));
      Test_Contexts.Set_Locale (Context, "es");
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Error_Output (Context) = "touch: marca de tiempo no válida 'nonsense'" & LF,
         "Spanish touch invalid timestamp diagnostic");
   end Test_Diagnostic_Locales;
