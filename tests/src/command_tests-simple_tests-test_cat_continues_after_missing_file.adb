separate (Command_Tests.Simple_Tests)

   procedure Test_Cat_Continues_After_Missing_File (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Missing : constant String := Fixture_Path ("missing-cat-file.bin");
      Later   : constant String := Fixture_Path ("reg-cat-later.bin");
   begin
      Write_File (Later, "later");

      Context.Initialize ("cat", Two_Args (Missing, Later));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "later", "cat continues after missing file");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "cat: '" & Missing & "': cannot read file" & Character'Val (10),
         "cat missing diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cat aggregate failure status");
   end Test_Cat_Continues_After_Missing_File;
