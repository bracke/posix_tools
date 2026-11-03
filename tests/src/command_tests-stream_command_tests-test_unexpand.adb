separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Unexpand (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("unexpand-input.txt");
      Missing : constant String := Fixture_Path ("unexpand-missing.txt");
      LF      : constant Character := Character'Val (10);
      HT      : constant Character := Character'Val (9);
      Wide    : constant String := Character'Val (16#E4#) & Character'Val (16#B8#) & Character'Val (16#AD#);

   begin
      Context.Initialize ("unexpand", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "        x");
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = HT & "x",
         "unexpand compresses leading blanks by default");

      Context.Initialize ("unexpand", One_Arg ("-a"));
      Test_Contexts.Set_Standard_Input (Context, "x       y");
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "x" & HT & "y",
         "unexpand -a compresses non-leading blanks");

      Context.Initialize ("unexpand", Two_Args ("-a", "-t3,6"));
      Test_Contexts.Set_Standard_Input (Context, "   x  y");
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = HT & "x" & HT & "y",
         "unexpand supports comma-separated tab stop lists");

      Context.Initialize ("unexpand", One_Arg ("-a"));
      Test_Contexts.Set_Standard_Input (Context, Wide & "      x");
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Wide & HT & "x",
         "unexpand uses display columns for wide UTF-8");

      Delete_If_Exists (Path);
      Write_File (Path, "    x" & LF & "  y");
      Context.Initialize ("unexpand", Two_Args ("-t4", Path));
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = HT & "x" & LF & "  y",
         "unexpand reads file operands and honors tab width");

      Context.Initialize ("unexpand", One_Arg ("-t4,3"));
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "unexpand rejects non-increasing tab stop lists");

      Context.Initialize ("unexpand", Two_Args ("-t", "0"));
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "unexpand rejects zero tab width");

      Context.Initialize ("unexpand", One_Arg (Missing));
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "unexpand reports missing file");

      Context.Initialize ("unexpand", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "    x");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "unexpand returns operational failure after output failure");

      Delete_If_Exists (Path);
   end Test_Unexpand;
