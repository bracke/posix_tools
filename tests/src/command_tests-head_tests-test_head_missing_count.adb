separate (Command_Tests.Head_Tests)

   procedure Test_Head_Missing_Count (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("head", One_Arg ("-n"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head missing count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "head: missing option argument '-n'" & Character'Val (10),
         "head missing count diagnostic");

      Context.Initialize ("head", One_Arg ("-c"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head missing byte count status");
   end Test_Head_Missing_Count;
