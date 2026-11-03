separate (Command_Tests.Head_Tests)

   procedure Test_Head_Invalid_Count (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("head", One_Arg ("-nabc"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "head invalid count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "head: invalid line count 'abc'" & Character'Val (10),
         "head invalid count diagnostic");

      Context.Initialize ("head", Two_Args ("-n", "-1"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head negative count status");

      Context.Initialize ("head", Two_Args ("-n", "+1"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head leading plus count status");

      Context.Initialize ("head", Two_Args ("-c", "abc"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head invalid byte count status");

      Context.Initialize ("head", Two_Args ("-n", "9223372036854775808"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head overflow count status");

   end Test_Head_Invalid_Count;
