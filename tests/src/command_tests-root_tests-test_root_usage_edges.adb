separate (Command_Tests.Root_Tests)

   procedure Test_Root_Usage_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("posix-tools", Two_Args ("list", "extra"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "root list extra status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: extra operand 'extra'" & LF,
         "root list extra diagnostic");

      Context.Initialize ("posix-tools", Three_Args ("help", "cat", "extra"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "root help extra status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: extra operand 'extra'" & LF,
         "root help extra diagnostic");

      Context.Initialize ("posix-tools", Two_Args ("help", "missing"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "root help unknown status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: unknown command 'missing'" & LF,
         "root help unknown diagnostic");
   end Test_Root_Usage_Edges;
