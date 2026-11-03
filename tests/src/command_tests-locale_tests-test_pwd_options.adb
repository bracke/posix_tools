separate (Command_Tests.Locale_Tests)

   procedure Test_Pwd_Options (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      Physical : constant String := "/physical/test";
   begin
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");

      Context.Initialize ("pwd", One_Arg ("-L"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "/logical/test" & Character'Val (10),
         "pwd -L output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -L status");

      Context.Initialize ("pwd", One_Arg ("-P"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & Character'Val (10),
         "pwd -P output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -P status");

      Context.Initialize ("pwd", Two_Args ("-L", "-P"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & Character'Val (10),
         "pwd last option wins");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd precedence status");

      Context.Initialize ("pwd", One_Arg ("operand"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "pwd operand status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "pwd: invalid operand 'operand'" & Character'Val (10),
         "pwd operand diagnostic");
   end Test_Pwd_Options;
