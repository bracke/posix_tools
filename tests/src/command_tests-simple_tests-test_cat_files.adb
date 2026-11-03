separate (Command_Tests.Simple_Tests)

   procedure Test_Cat_Files (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      First   : constant String := Fixture_Path ("reg-cat-first.bin");
      Second  : constant String := Fixture_Path ("reg-cat-second.bin");
   begin
      Write_File (First, "A" & Character'Val (0));
      Write_File (Second, "B");

      Context.Initialize ("cat", Two_Args (First, Second));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A" & Character'Val (0) & "B",
         "cat preserves ordered file bytes");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat files status");
   end Test_Cat_Files;
