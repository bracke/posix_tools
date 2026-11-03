separate (Command_Tests.Root_Tests)

   procedure Test_Root_List_Inventory_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("list"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Inventory_List_Output,
         "root list must match command inventory order");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "root inventory list status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "",
         "root inventory list stderr");
   end Test_Root_List_Inventory_Property;
