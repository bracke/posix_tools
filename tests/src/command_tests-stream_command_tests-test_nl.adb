separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Nl (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("nl-input.txt");
      Missing : constant String := Fixture_Path ("nl-missing.txt");
      LF      : constant Character := Character'Val (10);
      HT      : constant Character := Character'Val (9);

   begin
      Context.Initialize ("nl", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & LF & "b");
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "     1" & HT & "a" & LF & "      " & HT & LF
           & "     2" & HT & "b",
         "nl numbers non-empty stdin lines by default");

      Context.Initialize ("nl", One_Arg ("-ba"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & LF);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "     1" & HT & "a" & LF & "     2" & HT & LF,
         "nl -ba numbers blank lines");

      Context.Initialize ("nl", One_Arg ("-bn"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "      " & HT & "a" & LF,
         "nl -bn suppresses numbering");

      Delete_If_Exists (Path);
      Write_File (Path, "x" & LF & "y" & LF);
      Context.Initialize ("nl", Six_Args ("-v", "3", "-i", "2", "-w2", Path));
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = " 3" & HT & "x" & LF & " 5" & HT & "y" & LF,
         "nl honors start increment width and file operands");

      Context.Initialize ("nl", Three_Args ("-s", ": ", "-ba"));
      Test_Contexts.Set_Standard_Input (Context, "z" & LF);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "     1: z" & LF,
         "nl honors custom separators");

      Context.Initialize ("nl", Four_Args ("-ha", "-fa", "-ba", "-v3"));
      Test_Contexts.Set_Standard_Input
        (Context,
         "\:\:\:" & LF
         & "head" & LF
         & "\:\:" & LF
         & "body" & LF
         & "\:" & LF
         & "foot" & LF);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "     3" & HT & "head" & LF
           & "     4" & HT & "body" & LF
           & "     5" & HT & "foot" & LF,
         "nl processes default logical page delimiters");

      Context.Initialize ("nl", Five_Args ("-p", "-ha", "-d", "%%", "-v7"));
      Test_Contexts.Set_Standard_Input
        (Context,
         "%%%%%%" & LF
         & "first" & LF
         & "%%%%%%" & LF
         & "second" & LF);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "     7" & HT & "first" & LF
           & "     8" & HT & "second" & LF,
         "nl honors custom delimiters and no-restart");

      Context.Initialize ("nl", Two_Args ("-i", "0"));
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "nl rejects zero increment");

      Context.Initialize ("nl", One_Arg (Missing));
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "nl reports missing files");

      Context.Initialize ("nl", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "x");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "nl reports output failures");

      Delete_If_Exists (Path);
   end Test_Nl;
