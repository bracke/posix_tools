separate (Command_Tests.Locale_Tests)

   procedure Test_Identity_Locale_Invariance (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;

      function Expected (Command : String) return String is
      begin
         return
           "schema=1" & Character'Val (10)
           & "project=posix-tools" & Character'Val (10)
           & "command=" & Command & Character'Val (10)
           & "version=" & Posix_Tools.Version.Version_String & Character'Val (10);
      end Expected;

      procedure Check_Command (Command, Locale, Label : String) is
      begin
         Context.Initialize (Command, One_Arg ("--posix-tools-identify"));
         if Locale /= "" then
            Test_Contexts.Set_Locale (Context, Locale);
         end if;
         Command_Tests.Dispatch.Run (Command, Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "identity status " & Command & " " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Expected (Command),
            "identity output " & Command & " " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) = "",
            "identity stderr " & Command & " " & Label);
      end Check_Command;

      procedure Check_Root (Locale, Label : String) is
      begin
         Context.Initialize ("posix-tools", One_Arg ("--posix-tools-identify"));
         if Locale /= "" then
            Test_Contexts.Set_Locale (Context, Locale);
         end if;
         Posix_Tools.Commands.Root.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "root identity status " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Expected ("posix-tools"),
            "root identity output " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) = "",
            "root identity stderr " & Label);
      end Check_Root;
   begin
      for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Command : constant String := Posix_Tools.Command_Inventory.Executable (Index);
         begin
            Check_Command (Command, "", "default");
            Check_Command (Command, "en", "en");
            Check_Command (Command, "da", "da");
            Check_Command (Command, "zz-ZZ", "unknown");
         end;
      end loop;

      Check_Root ("", "default");
      Check_Root ("en", "en");
      Check_Root ("da", "da");
      Check_Root ("zz-ZZ", "unknown");
   end Test_Identity_Locale_Invariance;
