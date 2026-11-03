separate (Command_Tests.Simple_Tests)

   procedure Test_Cat_Standard_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "A" & Character'Val (0) & "B");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A" & Character'Val (0) & "B",
         "cat implicit stdin preserves bytes");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat implicit stdin status");

      Context.Initialize ("cat", Two_Args ("-", "-"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "cat repeated stdin does not rewind");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat repeated stdin status");

      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "cat stdin read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "cat: 'standard input': cannot read file" & Character'Val (10),
         "cat stdin read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cat stdin read failure status");

      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 3);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "cat stdin partial read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "cat: 'standard input': cannot read file" & Character'Val (10),
         "cat stdin partial read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cat stdin partial read failure status");
   end Test_Cat_Standard_Input;
