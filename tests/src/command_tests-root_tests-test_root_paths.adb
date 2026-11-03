separate (Command_Tests.Root_Tests)

   procedure Test_Root_Paths (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("paths"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      declare
         Output_Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root paths status");
         AUnit.Assertions.Assert (Contains (Output_Text, "basename: "), "root paths basename line");
         AUnit.Assertions.Assert (Contains (Output_Text, "cat: "), "root paths cat line");
         AUnit.Assertions.Assert (Contains (Output_Text, "dirname: "), "root paths dirname line");
         AUnit.Assertions.Assert (Contains (Output_Text, "echo: "), "root paths echo line");
         AUnit.Assertions.Assert (Contains (Output_Text, "false: "), "root paths false line");
         AUnit.Assertions.Assert (Contains (Output_Text, "head: "), "root paths head line");
         AUnit.Assertions.Assert (Contains (Output_Text, "pwd: "), "root paths pwd line");
         AUnit.Assertions.Assert (Contains (Output_Text, "tail: "), "root paths tail line");
         AUnit.Assertions.Assert (Contains (Output_Text, "true: "), "root paths true line");
         AUnit.Assertions.Assert (Contains (Output_Text, "wc: "), "root paths wc line");
      end;
   end Test_Root_Paths;
