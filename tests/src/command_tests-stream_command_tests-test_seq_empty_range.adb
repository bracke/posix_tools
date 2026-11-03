separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Seq_Empty_Range (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("seq", Two_Args ("2", "1"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "seq with an empty range writes nothing");

      Context.Initialize ("seq", Three_Args ("5", "-1", "6"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "seq with an empty descending range writes nothing");

      Context.Initialize ("seq", Two_Args ("9223372036854775807", "9223372036854775807"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "9223372036854775807" & LF,
         "seq ends the last number with a newline at the overflow limit");
   end Test_Seq_Empty_Range;
