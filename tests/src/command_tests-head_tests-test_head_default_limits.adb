separate (Command_Tests.Head_Tests)

   procedure Test_Head_Default_Limits (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Short   : constant String := Fixture_Path ("reg-head-default-short.txt");
      Long    : constant String := Fixture_Path ("reg-head-default-long.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Short, "1" & LF & "2" & LF & "3" & LF);
      Context.Initialize ("head", One_Arg (Short));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1" & LF & "2" & LF & "3" & LF,
         "head short default output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head short default status");

      Write_File
        (Long,
         "1" & LF & "2" & LF & "3" & LF & "4" & LF & "5" & LF & "6" & LF
         & "7" & LF & "8" & LF & "9" & LF & "10" & LF & "11" & LF & "12" & LF);
      Context.Initialize ("head", One_Arg (Long));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "1" & LF & "2" & LF & "3" & LF & "4" & LF & "5" & LF & "6" & LF
           & "7" & LF & "8" & LF & "9" & LF & "10" & LF,
         "head long default output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head long default status");
   end Test_Head_Default_Limits;
