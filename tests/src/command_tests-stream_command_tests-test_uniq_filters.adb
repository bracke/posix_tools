separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Uniq_Filters (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
      Composed   : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
      Decomposed : constant String := "e" & Character'Val (16#CC#) & Character'Val (16#81#);
   begin
      Context.Initialize ("uniq", Two_Args ("-d", "-u"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "a" & LF & "b" & LF);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "uniq -d -u writes nothing");

      Context.Initialize ("uniq", No_Args);
      Test_Contexts.Set_Locale (Context, "C");
      Test_Contexts.Set_Standard_Input (Context, Composed & LF & Decomposed & LF);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Composed & LF & Decomposed & LF,
         "uniq compares bytes in the C locale");

      Context.Initialize ("uniq", Two_Args ("-", "/nonexistent-directory/unique"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Error_Output (Context)
           = "uniq: '/nonexistent-directory/unique': cannot write file" & LF,
         "uniq reports an output file it cannot write");
   end Test_Uniq_Filters;
