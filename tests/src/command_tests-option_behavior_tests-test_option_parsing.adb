separate (Command_Tests.Option_Behavior_Tests)

   procedure Test_Option_Parsing (T : in out Fixture) is
      pragma Unreferenced (T);
      LF      : constant Character := Character'Val (10);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Data    : constant String := Work_Path ("option-parsing.txt");

      procedure Assert_Usage (Expected : String; Label : String);

      --  The command just run made the usage error Expected and wrote
      --  nothing else.
      procedure Assert_Usage (Expected : String; Label : String) is
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
            and then Test_Contexts.Error_Output (Context) = Expected & LF
            and then Test_Contexts.Output (Context) = "",
            Label);
      end Assert_Usage;
   begin
      Write_File (Data, "a:b:c" & LF & "plain" & LF);

      --  An option a command does not take is a usage error, not a file.
      Context.Initialize ("cat", Two_Args ("-x", Data));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      Assert_Usage ("cat: unknown option '-x'", "cat rejects an unknown option");

      Context.Initialize ("cat", Two_Args ("-u", Data));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a:b:c" & LF & "plain" & LF,
         "cat accepts the POSIX -u option");

      Context.Initialize ("head", Two_Args ("-x", Data));
      Posix_Tools.Commands.Head.Run (Context, Result);
      Assert_Usage ("head: unknown option '-x'", "head rejects an unknown option");

      Context.Initialize ("head", Three_Args ("-c", "3", Data));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "a:b",
         "head takes -c with a separate count");

      Context.Initialize ("head", Two_Args ("-n1", Data));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "a:b:c" & LF,
         "head takes -n with an attached count");

      Context.Initialize ("head", One_Arg ("-n"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      Assert_Usage ("head: missing option argument '-n'", "head reports a missing count");

      Context.Initialize ("cut", Two_Args ("-x", Data));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      Assert_Usage ("cut: unknown option '-x'", "cut rejects an unknown option");

      Context.Initialize ("cut", Three_Args ("-sd:", "-f2", Data));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "b" & LF,
         "cut takes -s grouped with -d and its delimiter");

      Context.Initialize ("cut", Three_Args ("-sf1", "-d:", Data));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "a" & LF,
         "cut takes -s grouped with -f and its list");

      Context.Initialize ("paste", Two_Args ("-x", Data));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      Assert_Usage ("paste: unknown option '-x'", "paste rejects an unknown option");

      Context.Initialize ("paste", Two_Args ("-sd,", Data));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a:b:c,plain" & LF,
         "paste takes -s grouped with -d and its list");

      Context.Initialize ("od", Two_Args ("-q", Data));
      Posix_Tools.Commands.Od.Run (Context, Result);
      Assert_Usage ("od: unknown option '-q'", "od rejects an unknown option");

      Context.Initialize ("od", Four_Args ("-An", "-tx1", "-N2", Data));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = " 61 3a" & LF,
         "od takes attached option arguments");

      Context.Initialize ("od", Three_Args ("-vAn", "-tx1", "-N1"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = " 61" & LF,
         "od takes -v grouped with -A and its base");

      Context.Initialize ("fold", Two_Args ("-x", Data));
      Posix_Tools.Commands.Fold.Run (Context, Result);
      Assert_Usage ("fold: unknown option '-x'", "fold names the unknown option character");

      Context.Initialize ("fold", Three_Args ("-bs", "-w3", Data));
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a:b" & LF & ":c" & LF & "pla" & LF & "in" & LF,
         "fold takes grouped -b and -s");

      Context.Initialize ("fold", Two_Args ("-sw3", Data));
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a:b" & LF & ":c" & LF & "pla" & LF & "in" & LF,
         "fold takes -s grouped with -w and its width");

      Context.Initialize ("pathchk", Two_Args ("-pq", "name"));
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      Assert_Usage ("pathchk: unknown option '-q'", "pathchk names the unknown option character");

      --  "--" ends the options.
      Context.Initialize ("nice", Two_Args ("--", "true"));
      Posix_Tools.Commands.Nice.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Nice_Adjustment (Context) = 10,
         "nice ends its options at --");

      Context.Initialize ("nice", Four_Args ("-n", "3", "--", "true"));
      Posix_Tools.Commands.Nice.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Nice_Adjustment (Context) = 3,
         "nice ends its options at -- after -n");

      Context.Initialize ("sleep", Two_Args ("--", "0"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Error_Output (Context) = "",
         "sleep ends its options at --");

      Context.Initialize ("tty", Two_Args ("-s", "--"));
      Test_Contexts.Set_Standard_Input_Is_Terminal (Context, False);
      Posix_Tools.Commands.Tty.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "",
         "tty ends its options at --");

      Context.Initialize ("tty", Two_Args ("--", "surplus"));
      Posix_Tools.Commands.Tty.Run (Context, Result);
      Assert_Usage ("tty: extra operand 'surplus'", "tty names a surplus operand after --");

      --  A host with no signals, as Windows, refuses -s TERM before "--".
      if Posix_Tools.Host_Adapters.Signals.Is_Supported (Posix_Tools.Host_Adapters.Signals.Terminate_Signal) then
         Context.Initialize ("kill", Four_Args ("-s", "TERM", "--", "not-a-process"));
         Posix_Tools.Commands.Kill.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
            and then Contains (Test_Contexts.Error_Output (Context), "'not-a-process'")
            and then not Contains (Test_Contexts.Error_Output (Context), "'--'"),
            "kill ends its options at --");
      end if;

      Context.Initialize ("getconf", Two_Args ("--", "PATH"));
      Posix_Tools.Commands.Getconf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "/bin:/usr/bin" & LF,
         "getconf ends its options at --");

      --  Too many operands name the first one too many.
      Context.Initialize ("tr", Three_Args ("-d", "a", "b"));
      Posix_Tools.Commands.Tr.Run (Context, Result);
      Assert_Usage ("tr: extra operand 'b'", "tr -d names its surplus operand");

      Context.Initialize ("tr", Four_Args ("a", "b", "c", "d"));
      Posix_Tools.Commands.Tr.Run (Context, Result);
      Assert_Usage ("tr: extra operand 'c'", "tr names its first surplus operand");

      Context.Initialize ("tr", One_Arg ("a"));
      Posix_Tools.Commands.Tr.Run (Context, Result);
      Assert_Usage ("tr: missing operand", "tr still reports a missing operand");
   end Test_Option_Parsing;
