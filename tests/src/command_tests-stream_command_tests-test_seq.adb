separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Seq (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("seq", One_Arg ("3"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1" & LF & "2" & LF & "3" & LF,
         "seq one operand starts at one");

      Context.Initialize ("seq", Two_Args ("3", "5"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "3" & LF & "4" & LF & "5" & LF,
         "seq two operands uses unit increment");

      Context.Initialize ("seq", Three_Args ("5", "-2", "1"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "5" & LF & "3" & LF & "1" & LF,
         "seq supports negative increments");

      Context.Initialize ("seq", Three_Args ("0.1", "0.1", "0.3"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0.1" & LF & "0.2" & LF & "0.3" & LF,
         "seq supports deterministic decimal increments");

      Context.Initialize ("seq", Three_Args ("1e1", "5e0", "2e1"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "10" & LF & "15" & LF & "20" & LF,
         "seq supports positive exponent notation");

      Context.Initialize ("seq", Three_Args ("1e-1", "1e-1", "3e-1"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0.1" & LF & "0.2" & LF & "0.3" & LF,
         "seq supports negative exponent notation");

      Context.Initialize ("seq", One_Arg ("1e999999999999999999999999999999999999999"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "seq rejects overflowing exponent");

      Context.Initialize ("seq", One_Arg ("0.99999999999999999999"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "seq rejects overflowing mantissa");

      Context.Initialize ("seq", Three_Args ("0.1", "0.1", "0.3"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0,1" & LF & "0,2" & LF & "0,3" & LF,
         "seq uses locale decimal separator");

      Context.Initialize ("seq", Three_Args ("0.1", "0.1", "0.3"));
      Test_Contexts.Set_Locale (Context, "en");
      Test_Contexts.Set_Environment_Value (Context, "LC_NUMERIC", "da");
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0,1" & LF & "0,2" & LF & "0,3" & LF,
         "seq LC_NUMERIC overrides context locale");

      Context.Initialize ("seq", Four_Args ("-s", ",", "1", "3"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1,2,3" & LF,
         "seq supports custom separators");

      Context.Initialize ("seq", Three_Args ("-w", "8", "10"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "08" & LF & "09" & LF & "10" & LF,
         "seq supports equal-width output");

      Context.Initialize ("seq", Five_Args ("-f", "n=%04.1f", "1", "1", "3"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "n=01.0" & LF & "n=02.0" & LF & "n=03.0" & LF,
         "seq supports printf-style decimal formatting");

      Context.Initialize
        ("seq", Three_Args ("-f%999999999999999999999999999999f", "1", "2"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1" & LF & "2" & LF,
         "seq overflowing format width uses default formatting");

      Context.Initialize ("seq", Five_Args ("-f", "n=%04.1f", "1", "1", "3"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "n=01,0" & LF & "n=02,0" & LF & "n=03,0" & LF,
         "seq formats numbers through locale data");

      Context.Initialize ("seq", Three_Args ("1", "0", "3"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "seq rejects zero increment");

      Context.Initialize ("seq", One_Arg ("abc"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "seq rejects invalid integers");

      Context.Initialize ("seq", Four_Args ("1", "2", "3", "4"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "seq rejects extra operands");

      Context.Initialize ("seq", One_Arg ("3"));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "seq reports output failure");
   end Test_Seq;
