separate (Command_Tests.Locale_Tests)

   procedure Test_Presentation_Styling (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      ESC     : constant Character := Character'Val (27);
   begin
      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Never);
      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (not Contains (Test_Contexts.Output (Context), "" & ESC), "unstyled help has no ANSI");
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "Usage: cat "), "unstyled semantic help");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Always);
      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "" & ESC & "["), "styled help has ANSI");
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "Usage"), "styled help keeps usage text");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "--help"),
         "styled help keeps option spelling");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Automatic);
      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, False);
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, True);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Output (Context), "" & ESC),
         "automatic redirected help has no ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "Usage: cat "),
         "automatic redirected help keeps usage");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Never);
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Output (Context), "" & ESC),
         "unstyled root help has no ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "Usage: posix-tools"),
         "unstyled root help");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Always);
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "" & ESC & "["), "styled root help has ANSI");
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "Usage"), "styled root help keeps usage");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "help, version, list, paths, verify"),
         "styled root help keeps commands");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Automatic);
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, False);
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, True);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Output (Context), "" & ESC),
         "automatic redirected root help has no ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "Usage: posix-tools"),
         "automatic redirected root help keeps usage");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Never);
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, True);
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Error_Output (Context), "" & ESC),
         "unstyled diagnostic has no ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "dirname: extra operand 'second'"),
         "unstyled diagnostic keeps text");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Always);
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, False);
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "" & ESC & "["),
         "styled diagnostic has ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "dirname: extra operand 'second'"),
         "styled diagnostic keeps text");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Automatic);
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, False);
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Error_Output (Context), "" & ESC),
         "automatic redirected diagnostic has no ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "dirname: extra operand 'second'"),
         "automatic redirected diagnostic keeps text");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Automatic);
   end Test_Presentation_Styling;
