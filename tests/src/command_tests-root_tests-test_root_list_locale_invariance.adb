separate (Command_Tests.Root_Tests)

   procedure Test_Root_List_Locale_Invariance (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      Expected : constant String := Inventory_List_Output;

      procedure Check (Locale, Label : String) is
      begin
         Context.Initialize ("posix-tools", One_Arg ("list"));
         if Locale /= "" then
            Test_Contexts.Set_Locale (Context, Locale);
         end if;
         Posix_Tools.Commands.Root.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "root list locale status " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Expected,
            "root list locale output " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) = "",
            "root list locale stderr " & Label);
      end Check;
   begin
      Check ("", "default");
      Check ("en", "en");
      Check ("da", "da");
      Check ("zz-ZZ", "unknown");
   end Test_Root_List_Locale_Invariance;
