separate (Command_Tests.Root_Tests)

   procedure Test_Root_Command_Help_Uses_Command_Metadata (T : in out Fixture) is
      pragma Unreferenced (T);
      Cat_Context  : Test_Contexts.Capturing_Context;
      Root_Context : Test_Contexts.Capturing_Context;
      Cat_Result   : Posix_Tools.Commands.Results.Result;
      Root_Result  : Posix_Tools.Commands.Results.Result;
   begin
      Cat_Context.Initialize ("cat", One_Arg ("--help"));
      Posix_Tools.Commands.Cat.Run (Cat_Context, Cat_Result);

      Root_Context.Initialize ("posix-tools", Two_Args ("help", "cat"));
      Posix_Tools.Commands.Root.Run (Root_Context, Root_Result);

      AUnit.Assertions.Assert
        (Cat_Result.Status = Posix_Tools.Exit_Status.Success,
         "cat direct help status");
      AUnit.Assertions.Assert
        (Root_Result.Status = Posix_Tools.Exit_Status.Success,
         "root command help status");
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Root_Context) = Test_Contexts.Output (Cat_Context),
         "root command help must reuse command metadata");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Root_Context) = "",
         "root command help stderr");
   end Test_Root_Command_Help_Uses_Command_Metadata;
