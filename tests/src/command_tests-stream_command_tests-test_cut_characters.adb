separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Cut_Characters (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
      E_Acute : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
      Line    : constant String := "h" & E_Acute & "llo" & LF;

      procedure Check (Arguments : Posix_Tools.Arguments.Vector; Locale, Input, Expected, Label : String);

      procedure Check (Arguments : Posix_Tools.Arguments.Vector; Locale, Input, Expected, Label : String) is
      begin
         Context.Initialize ("cut", Arguments);
         Test_Contexts.Set_Locale (Context, Locale);
         Test_Contexts.Set_Standard_Input (Context, Input);
         Posix_Tools.Commands.Cut.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = Expected,
            Label);
      end Check;
   begin
      Check (One_Arg ("-c2-3"), "en_US.UTF-8", Line, E_Acute & "l" & LF, "cut -c selects UTF-8 characters");
      Check (One_Arg ("-c2"), "C", Line, Character'Val (16#C3#) & LF, "cut -c selects bytes in the C locale");
      Check (One_Arg ("-b2"), "en_US.UTF-8", Line, Character'Val (16#C3#) & LF, "cut -b selects bytes");
      Check (One_Arg ("-c3"), "en_US.UTF-8", "a" & Character'Val (16#FF#) & "b" & LF, "b" & LF,
             "cut -c counts an invalid byte as one character");
      Check (Two_Args ("-n", "-b2"), "en_US.UTF-8", Line, "" & LF, "cut -n -b drops a range that splits a character");
      Check (Two_Args ("-n", "-b3"), "en_US.UTF-8", Line, E_Acute & LF,
             "cut -n -b moves a low end back to the start of its character");
      Check (Two_Args ("-n", "-b1-2"), "en_US.UTF-8", Line, "h" & LF,
             "cut -n -b moves a high end back before a split character");
      Check (Two_Args ("-n", "-b2-"), "en_US.UTF-8", Line, E_Acute & "llo" & LF, "cut -n -b keeps whole characters");
      Check (Two_Args ("-d:", "-f1,2"), "C", ":a" & LF, ":a" & LF,
             "cut -f keeps the delimiter after an empty first field");
      Check (Two_Args ("-d" & E_Acute, "-f2"), "en_US.UTF-8", Line, "llo" & LF,
             "cut -d takes a multibyte delimiter in a UTF-8 locale");
   end Test_Cut_Characters;
