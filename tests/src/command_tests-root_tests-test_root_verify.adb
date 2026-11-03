separate (Command_Tests.Root_Tests)

   procedure Test_Root_Verify (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("verify"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      declare
         Output_Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Expected_Verify_Status (Output_Text),
            "root verify fails exactly when a command is not ok");
         AUnit.Assertions.Assert (Contains (Output_Text, "basename: "), "root verify basename line");
         AUnit.Assertions.Assert (Contains (Output_Text, "cat: "), "root verify cat line");
         AUnit.Assertions.Assert (Contains (Output_Text, "dirname: "), "root verify dirname line");
         AUnit.Assertions.Assert (Contains (Output_Text, "echo: "), "root verify echo line");
         AUnit.Assertions.Assert (Contains (Output_Text, "false: "), "root verify false line");
         AUnit.Assertions.Assert (Contains (Output_Text, "head: "), "root verify head line");
         AUnit.Assertions.Assert (Contains (Output_Text, "pwd: "), "root verify pwd line");
         AUnit.Assertions.Assert (Contains (Output_Text, "tail: "), "root verify tail line");
         AUnit.Assertions.Assert (Contains (Output_Text, "true: "), "root verify true line");
         AUnit.Assertions.Assert (Contains (Output_Text, "wc: "), "root verify wc line");
      end;
   end Test_Root_Verify;
