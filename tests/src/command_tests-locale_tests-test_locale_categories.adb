separate (Command_Tests.Locale_Tests)

   procedure Test_Locale_Categories (T : in out Fixture) is
      pragma Unreferenced (T);
      package Contexts renames Posix_Tools.Commands.Contexts;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
      AE      : constant String := Character'Val (16#C3#) & Character'Val (16#A6#);
      O_Slash : constant String := Character'Val (16#C3#) & Character'Val (16#B8#);
      A_Ring  : constant String := Character'Val (16#C3#) & Character'Val (16#A5#);
      --  Danish collates these as z, ae, o-slash, a-ring; bytes put a-ring first.
      Danish_Letters : constant String := A_Ring & LF & "z" & LF & O_Slash & LF & AE & LF;
   begin
      --  Each category follows LC_ALL, then its own variable, then LANG.
      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Environment_Value (Context, "LANG", "C");
      Test_Contexts.Set_Environment_Value (Context, "LC_MESSAGES", "da");
      Test_Contexts.Set_Environment_Value (Context, "LC_COLLATE", "es");
      AUnit.Assertions.Assert
        (Context.Category_Locale (Contexts.Collation) = "es"
         and then Context.Category_Locale (Contexts.Messages) = "da"
         and then Context.Effective_Locale = "da"
         and then Context.Category_Locale (Contexts.Character_Classification) = "C"
         and then Context.Category_Locale (Contexts.Numeric) = "C"
         and then Context.Category_Locale (Contexts.Time) = "C",
         "each locale category reads its own variable before LANG");
      Test_Contexts.Set_Environment_Value (Context, "LC_ALL", "en");
      AUnit.Assertions.Assert
        (Context.Category_Locale (Contexts.Collation) = "en"
         and then Context.Category_Locale (Contexts.Messages) = "en",
         "LC_ALL overrides every locale category");

      --  The messages locale no longer decides collation.
      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Environment_Value (Context, "LC_MESSAGES", "da");
      Test_Contexts.Set_Environment_Value (Context, "LANG", "C");
      Test_Contexts.Set_Standard_Input (Context, Danish_Letters);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "z" & LF & A_Ring & LF & AE & LF & O_Slash & LF,
         "sort collates by LANG, not LC_MESSAGES");

      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Environment_Value (Context, "LC_MESSAGES", "C");
      Test_Contexts.Set_Environment_Value (Context, "LC_COLLATE", "da");
      Test_Contexts.Set_Standard_Input (Context, Danish_Letters);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "z" & LF & AE & LF & O_Slash & LF & A_Ring & LF,
         "sort collates by LC_COLLATE whatever LC_MESSAGES says");

      --  Nor character classification.
      Context.Initialize ("cut", One_Arg ("-c2"));
      Test_Contexts.Set_Environment_Value (Context, "LC_MESSAGES", "en_US.UTF-8");
      Test_Contexts.Set_Environment_Value (Context, "LC_CTYPE", "C");
      Test_Contexts.Set_Standard_Input (Context, "h" & Character'Val (16#C3#) & Character'Val (16#A9#) & LF);
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Character'Val (16#C3#) & LF,
         "cut counts bytes under LC_CTYPE=C whatever LC_MESSAGES says");

      --  And diagnostics follow LC_MESSAGES, not LC_COLLATE.
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Test_Contexts.Set_Environment_Value (Context, "LC_COLLATE", "da");
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "dirname: extra operand 'second'" & LF,
         "diagnostics ignore LC_COLLATE");

      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Test_Contexts.Set_Environment_Value (Context, "LANG", "C");
      Test_Contexts.Set_Environment_Value (Context, "LC_MESSAGES", "da");
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "dirname: ekstra operand 'second'" & LF,
         "diagnostics follow LC_MESSAGES before LANG");
   end Test_Locale_Categories;
