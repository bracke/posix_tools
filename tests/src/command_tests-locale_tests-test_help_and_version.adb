separate (Command_Tests.Locale_Tests)

   procedure Test_Help_And_Version (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("cat", One_Arg ("--help"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: cat [OPTION]... [OPERAND]..." & LF
           & "Ada implementation in the posix-tools package." & LF
           & "Options:" & LF
           & "  --help     display this help and exit" & LF
           & "  --version  display version information and exit" & LF,
         "cat help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat help status");

      Context.Initialize ("cat", One_Arg ("--version"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "cat (posix-tools) " & Posix_Tools.Version.Version_String & LF,
         "cat version output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat version status");
   end Test_Help_And_Version;
