separate (Command_Tests.Root_Tests)

   procedure Test_Root_Command_Help_Inventory_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      Direct_Context : Test_Contexts.Capturing_Context;
      Root_Context   : Test_Contexts.Capturing_Context;
      Direct_Result  : Posix_Tools.Commands.Results.Result;
      Root_Result    : Posix_Tools.Commands.Results.Result;
   begin
      for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Command : constant String := Posix_Tools.Command_Inventory.Executable (Index);
         begin
            Direct_Context.Initialize (Command, One_Arg ("--help"));
            Command_Tests.Dispatch.Run (Command, Direct_Context, Direct_Result);

            Root_Context.Initialize ("posix-tools", Two_Args ("help", Command));
            Posix_Tools.Commands.Root.Run (Root_Context, Root_Result);

            AUnit.Assertions.Assert
              (Direct_Result.Status = Posix_Tools.Exit_Status.Success,
               "direct help status for " & Command);
            AUnit.Assertions.Assert
              (Root_Result.Status = Posix_Tools.Exit_Status.Success,
               "root help status for " & Command);
            --  grep writes its own option summary, as its executable always
            --  has; the root names only its shared metadata.
            AUnit.Assertions.Assert
              (Command = "grep"
               or else Test_Contexts.Output (Root_Context) = Test_Contexts.Output (Direct_Context),
               "root help must match direct help for " & Command);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Root_Context) = "",
               "root help stderr for " & Command);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Direct_Context) = "",
               "direct help stderr for " & Command);
         end;
      end loop;
   end Test_Root_Command_Help_Inventory_Property;
