separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Tr_Streams_Characters (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
      E_Acute : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
      Upper_E_Acute : constant String := Character'Val (16#C3#) & Character'Val (16#89#);
      Alpha   : constant String := Character'Val (16#CE#) & Character'Val (16#B1#);
      Gamma   : constant String := Character'Val (16#CE#) & Character'Val (16#B3#);
      Long    : constant String (1 .. 40_000) := [others => 'y'];

      procedure Check (Arguments : Posix_Tools.Arguments.Vector; Locale, Input, Expected, Label : String);

      procedure Check (Arguments : Posix_Tools.Arguments.Vector; Locale, Input, Expected, Label : String) is
      begin
         Context.Initialize ("tr", Arguments);
         Test_Contexts.Set_Locale (Context, Locale);
         Test_Contexts.Set_Standard_Input (Context, Input);
         Posix_Tools.Commands.Tr.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = Expected,
            Label);
      end Check;
   begin
      Check (Two_Args (E_Acute, "E"), "en_US.UTF-8", "h" & E_Acute & "llo", "hEllo",
             "tr translates a multibyte character");
      Check (Two_Args ("a-z" & E_Acute, "A-Z" & Upper_E_Acute), "en_US.UTF-8", "h" & E_Acute & "llo",
             "H" & Upper_E_Acute & "LLO", "tr maps multibyte characters by position");
      Check (Two_Args (Alpha & "-" & Gamma, "abc"), "en_US.UTF-8", Gamma & Alpha, "ca",
             "tr ranges run over code points");
      Check (Two_Args ("-d", E_Acute), "en_US.UTF-8", "a" & E_Acute & "b", "ab", "tr deletes a multibyte character");
      Check (Three_Args ("-c", "a" & LF, "X"), "en_US.UTF-8", "a" & E_Acute & "b" & LF, "aXX" & LF,
             "tr complements by character");
      Check (Two_Args (E_Acute, "XY"), "C", E_Acute, "XY", "tr works on bytes in the C locale");
      Check (Two_Args ("-cs", "a"), "C", "aabbccdd" & LF, "aabcd" & LF,
             "tr -c -s squeezes the complement of SET1");
      Check (Three_Args ("-cs", "a", "x"), "C", "aabbcc", "aax", "tr -c -s squeezes SET2");
      Check (Two_Args ("y", "n"), "C", Long, [1 .. Long'Length => 'n'], "tr translates input of several chunks");

      Context.Initialize ("tr", Two_Args ("y", "n"));
      Test_Contexts.Set_Standard_Input (Context, Long);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 20_000);
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context)'Length >= 16_384
         and then Test_Contexts.Error_Output (Context) = "tr: 'standard input': cannot read file" & LF,
         "tr writes as it reads and reports a read error");
   end Test_Tr_Streams_Characters;
