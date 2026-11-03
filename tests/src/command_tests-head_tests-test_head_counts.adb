separate (Command_Tests.Head_Tests)

   procedure Test_Head_Counts (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-head-counts.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Path, "a" & LF & "b" & LF & "c");

      Context.Initialize ("head", Two_Args ("-n2", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "head -n2 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head -n2 status");

      Context.Initialize ("head", Three_Args ("-n", "0", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "head zero output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head zero status");

      Context.Initialize ("head", Three_Args ("-n", "9", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & LF & "b" & LF & "c",
         "head preserves final partial line");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head large count status");

      Context.Initialize ("head", Five_Args ("-n", "1", "-n", "2", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & LF & "b" & LF,
         "head repeated -n uses last count");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head repeated -n status");
   end Test_Head_Counts;
