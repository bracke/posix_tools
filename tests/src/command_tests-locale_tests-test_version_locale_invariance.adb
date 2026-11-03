separate (Command_Tests.Locale_Tests)

   procedure Test_Version_Locale_Invariance (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);

      procedure Check_Command (Command, Locale, Label : String) is
         --  grep names its engine and license, as its executable always has.
         Expected : constant String :=
           (if Command = "grep"
            then "grep " & Posix_Tools.Version.Version_String & LF & "engine greplib" & LF & "license MIT" & LF
            else Command & " (posix-tools) " & Posix_Tools.Version.Version_String & LF);
      begin
         Context.Initialize (Command, One_Arg ("--version"));
         if Locale /= "" then
            Test_Contexts.Set_Locale (Context, Locale);
         end if;
         Command_Tests.Dispatch.Run (Command, Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "version status " & Command & " " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Expected,
            "version output " & Command & " " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) = "",
            "version stderr " & Command & " " & Label);
      end Check_Command;

      procedure Check_Root (Locale, Label : String) is
         Expected : constant String :=
           "posix-tools " & Posix_Tools.Version.Version_String & LF;

         procedure Check_Root_Args
           (Args      : Posix_Tools.Arguments.Vector;
            Arg_Label : String)
         is
         begin
            Context.Initialize ("posix-tools", Args);
            if Locale /= "" then
               Test_Contexts.Set_Locale (Context, Locale);
            end if;
            Posix_Tools.Commands.Root.Run (Context, Result);
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "root version status " & Label & " " & Arg_Label);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Expected,
               "root version output " & Label & " " & Arg_Label);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Context) = "",
               "root version stderr " & Label & " " & Arg_Label);
         end Check_Root_Args;
      begin
         Check_Root_Args (One_Arg ("--version"), "extension");
         Check_Root_Args (One_Arg ("version"), "subcommand");
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
   end Test_Version_Locale_Invariance;
