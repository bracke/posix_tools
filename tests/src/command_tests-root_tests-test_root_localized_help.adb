separate (Command_Tests.Root_Tests)

   procedure Test_Root_Localized_Help (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Brug: posix-tools <command> [operand]" & LF
           & "Kommandoer: help, version, list, paths, verify" & LF,
         "root localized help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root localized help status");

      Context.Initialize ("posix-tools", One_Arg ("bogus"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "root localized unknown subcommand status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: ukendt underkommando 'bogus'" & LF,
         "root localized unknown subcommand diagnostic");

      Context.Initialize ("posix-tools", Two_Args ("help", "bogus"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "root localized unknown help topic status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: ukendt kommando 'bogus'" & LF,
         "root localized unknown help topic diagnostic");

      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Locale (Context, "es");
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Uso: posix-tools <command> [operand]" & LF
           & "Comandos: help, version, list, paths, verify" & LF,
         "root Spanish help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root Spanish help status");
   end Test_Root_Localized_Help;
