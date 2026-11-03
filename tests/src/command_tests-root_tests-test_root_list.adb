separate (Command_Tests.Root_Tests)

   procedure Test_Root_List (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      Expected : constant String := Inventory_List_Output;
   begin
      Context.Initialize ("posix-tools", One_Arg ("list"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected, "root list output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root list status");
   end Test_Root_List;
