separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Fold (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("fold-input.txt");
      Missing : constant String := Fixture_Path ("fold-missing.txt");
      LF      : constant Character := Character'Val (10);
      Wide    : constant String := Character'Val (16#E4#) & Character'Val (16#B8#) & Character'Val (16#AD#);
   begin
      Context.Initialize ("fold", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdefghijklmnopqrstuvwxyz");
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "abcdefghijklmnopqrstuvwxyz",
         "fold leaves short standard input unchanged");

      Context.Initialize ("fold", Two_Args ("-w", "5"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghijkl");
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "abcde" & LF & "fghij" & LF & "kl",
         "fold -w wraps standard input");

      Context.Initialize ("fold", Two_Args ("-w", "4"));
      Test_Contexts.Set_Standard_Input (Context, Wide & Wide & "x");
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Wide & Wide & LF & "x",
         "fold wraps by display columns without splitting UTF-8 sequences");

      Context.Initialize ("fold", Two_Args ("-w4", Path));
      Delete_If_Exists (Path);
      Write_File (Path, "abcd" & LF & "efghi" & LF);
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "abcd" & LF & "efgh" & LF & "i" & LF,
         "fold reads and wraps file operands");

      Context.Initialize ("fold", Three_Args ("-s", "-w", "8"));
      Test_Contexts.Set_Standard_Input (Context, "alpha beta gamma");
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "alpha " & LF & "beta " & LF & "gamma",
         "fold -s breaks at blanks");

      Context.Initialize ("fold", Two_Args ("-w", "0"));
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "fold rejects zero width");

      Context.Initialize ("fold", One_Arg (Missing));
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "fold reports missing file");

      Context.Initialize ("fold", Two_Args ("-w", "4"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "fold returns operational failure after output failure");

      Delete_If_Exists (Path);
   end Test_Fold;
