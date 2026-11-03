separate (Command_Tests.Head_Tests)

   procedure Test_Head_Multiple_File_Headers (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      First   : constant String := Fixture_Path ("reg-head-header-first.txt");
      Second  : constant String := Fixture_Path ("reg-head-header-second.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (First, "a" & LF & "b" & LF);
      Write_File (Second, "c" & LF & "d" & LF);

      Context.Initialize ("head", Four_Args ("-n", "1", First, Second));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "==> " & First & " <==" & LF
           & "a" & LF
           & LF
           & "==> " & Second & " <==" & LF
           & "c" & LF,
         "head multiple file headers");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head header status");
   end Test_Head_Multiple_File_Headers;
