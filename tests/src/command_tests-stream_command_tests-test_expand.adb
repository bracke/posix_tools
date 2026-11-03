separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Expand (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("expand-input.txt");
      Missing : constant String := Fixture_Path ("expand-missing.txt");
      LF      : constant Character := Character'Val (10);
      HT      : constant Character := Character'Val (9);
      BS      : constant Character := Character'Val (8);
      Wide    : constant String := Character'Val (16#E4#) & Character'Val (16#B8#) & Character'Val (16#AD#);
      Acute   : constant String := Character'Val (16#CC#) & Character'Val (16#81#);

   begin
      Context.Initialize ("expand", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a" & HT & "b");
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a       b",
         "expand uses default eight-column tab stops");

      Context.Initialize ("expand", Two_Args ("-t", "4"));
      Test_Contexts.Set_Standard_Input (Context, "ab" & HT & "c" & LF & HT & "d");
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab  c" & LF & "    d",
         "expand -t changes the tab width and resets after newline");

      Context.Initialize ("expand", Two_Args ("-t", "3,6"));
      Test_Contexts.Set_Standard_Input (Context, "a" & HT & "b" & HT & "c");
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a  b  c",
         "expand supports comma-separated tab stop lists");

      Context.Initialize ("expand", No_Args);
      Test_Contexts.Set_Standard_Input (Context, Wide & HT & "x" & LF & "e" & Acute & HT & "x");
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Wide & "      x" & LF & "e" & Acute & "       x",
         "expand uses display columns for wide and combining UTF-8");

      Context.Initialize ("expand", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc" & BS & HT & "x");
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "abc" & BS & "      x",
         "expand treats backspace as moving one display column left");

      Delete_If_Exists (Path);
      Write_File (Path, "x" & HT & "y");
      Context.Initialize ("expand", Two_Args ("-t4", Path));
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "x   y",
         "expand reads file operands");

      Context.Initialize ("expand", One_Arg ("-t4,3"));
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "expand rejects non-increasing tab stop lists");

      Context.Initialize ("expand", Two_Args ("-t", "0"));
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "expand rejects zero tab width");

      Context.Initialize ("expand", One_Arg (Missing));
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "expand reports missing file");

      Context.Initialize ("expand", One_Arg ("-t4"));
      Test_Contexts.Set_Standard_Input (Context, "a" & HT);
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "expand returns operational failure after output failure");

      Delete_If_Exists (Path);
   end Test_Expand;
