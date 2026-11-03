separate (Command_Tests.Locale_Tests)

   procedure Test_Help_Locales (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      declare
         Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "Danish help status");
         AUnit.Assertions.Assert (Contains (Text, "Brug: cat "), "Danish help usage heading");
         AUnit.Assertions.Assert (Contains (Text, "Valgmuligheder:"), "Danish help options heading");
         AUnit.Assertions.Assert (Contains (Text, "--help"), "Danish help preserves option spelling");
         AUnit.Assertions.Assert (not Contains (Text, "posix_tools."), "Danish help no message-key leak");
      end;

      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Locale (Context, "zz-ZZ");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      declare
         Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Contains (Text, "Usage: cat "), "unknown locale fallback usage");
         AUnit.Assertions.Assert (not Contains (Text, "posix_tools."), "unknown locale no message-key leak");
      end;

      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Locale (Context, "es");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      declare
         Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "Spanish help status");
         AUnit.Assertions.Assert (Contains (Text, "Uso: cat "), "Spanish help usage heading");
         AUnit.Assertions.Assert (Contains (Text, "Opciones:"), "Spanish help options heading");
         AUnit.Assertions.Assert
           (Contains (Text, "muestra esta ayuda y termina"),
            "Spanish help option description");
         AUnit.Assertions.Assert (Contains (Text, "--version"), "Spanish help preserves option spelling");
         AUnit.Assertions.Assert (not Contains (Text, "posix_tools."), "Spanish help no message-key leak");
      end;

      AUnit.Assertions.Assert
        (Posix_Tools.Localization.Text
           ("es", "posix_tools.test.missing_message", "FALLBACK_TEXT") = "FALLBACK_TEXT",
         "missing message falls back to caller default");
   end Test_Help_Locales;
