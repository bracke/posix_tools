separate (Command_Tests.Simple_Tests)

   procedure Test_Echo_Extensions_Are_Sole_Argument (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("echo", Two_Args ("--help", "value"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "--help value" & Character'Val (10),
         "echo treats non-sole --help as data");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo data status");

      Context.Initialize ("echo", One_Arg ("--version"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "echo (posix-tools) " & Posix_Tools.Version.Version_String & Character'Val (10),
         "echo version output");

      Context.Initialize ("echo", Two_Args ("--posix-tools-identify", "value"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "--posix-tools-identify value" & Character'Val (10),
         "echo treats non-sole identity as data");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo identity data status");
   end Test_Echo_Extensions_Are_Sole_Argument;
