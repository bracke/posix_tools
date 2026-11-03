separate (Command_Tests.Root_Tests)

   procedure Test_Root_Paths_Verify_Inventory_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("paths"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "root paths inventory status");
      Assert_Inventory_Status_Lines
        (Test_Contexts.Output (Context),
         "root paths inventory");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "",
         "root paths inventory stderr");

      Context.Initialize ("posix-tools", One_Arg ("verify"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Expected_Verify_Status (Test_Contexts.Output (Context)),
         "root verify inventory status");
      Assert_Inventory_Status_Lines
        (Test_Contexts.Output (Context),
         "root verify inventory");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "",
         "root verify inventory stderr");
   end Test_Root_Paths_Verify_Inventory_Property;
