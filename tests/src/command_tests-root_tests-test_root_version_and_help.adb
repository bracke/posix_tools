separate (Command_Tests.Root_Tests)

   procedure Test_Root_Version_And_Help (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("version"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "posix-tools " & Posix_Tools.Version.Version_String & Character'Val (10),
         "root version output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root version status");

      Context.Initialize ("posix-tools", One_Arg ("--version"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "posix-tools " & Posix_Tools.Version.Version_String & Character'Val (10),
         "root --version output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root --version status");

      Context.Initialize ("posix-tools", One_Arg ("--help"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: posix-tools [OPTION]... [OPERAND]..." & Character'Val (10)
           & "Ada implementation in the posix-tools package." & Character'Val (10)
           & "Options:" & Character'Val (10)
           & "  --help     display this help and exit" & Character'Val (10)
           & "  --version  display version information and exit" & Character'Val (10),
         "root --help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root --help status");

      Context.Initialize ("posix-tools", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "schema=1" & Character'Val (10)
           & "project=posix-tools" & Character'Val (10)
           & "command=posix-tools" & Character'Val (10)
           & "version=" & Posix_Tools.Version.Version_String & Character'Val (10),
         "root identity output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root identity status");

      Context.Initialize ("posix-tools", No_Args);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: posix-tools <command> [operand]" & Character'Val (10)
           & "Commands: help, version, list, paths, verify" & Character'Val (10),
         "root default help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root default help status");
   end Test_Root_Version_And_Help;
