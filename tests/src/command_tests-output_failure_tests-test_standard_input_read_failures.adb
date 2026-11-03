separate (Command_Tests.Output_Failure_Tests)

   procedure Test_Standard_Input_Read_Failures (T : in out Fixture) is
      pragma Unreferenced (T);
      LF      : constant Character := Character'Val (10);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;

      procedure Check (Name : String; Output : String);

      procedure Check (Name : String; Output : String) is
      begin
         AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Output, Name & " stdin read failure output");
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) = Name & ": 'standard input': cannot read file" & LF,
            Name & " stdin read failure diagnostic");
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            Name & " stdin read failure status");
      end Check;
   begin
      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "b" & LF & "a" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      Check ("sort", "");

      Context.Initialize ("sort", One_Arg ("-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & LF & "a" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      Check ("sort", "");

      Context.Initialize ("uniq", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "a" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      Check ("uniq", "");

      Context.Initialize ("file", One_Arg ("-"));
      Test_Contexts.Set_Standard_Input (Context, "text" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.File.Run (Context, Result);
      Check ("file", "");

      Context.Initialize ("xargs", One_Arg ("true"));
      Test_Contexts.Set_Standard_Input (Context, "a b" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      Check ("xargs", "");
   end Test_Standard_Input_Read_Failures;
