separate (Command_Tests.Stream_Command_Tests)

   procedure Test_Sort_Ordering_Rules (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);

      procedure Check (Arguments : Posix_Tools.Arguments.Vector; Input, Expected, Label : String);

      procedure Check (Arguments : Posix_Tools.Arguments.Vector; Input, Expected, Label : String) is
      begin
         Context.Initialize ("sort", Arguments);
         Test_Contexts.Set_Locale (Context, "C");
         Test_Contexts.Set_Standard_Input (Context, Input);
         Posix_Tools.Commands.Sort.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = Expected,
            Label);
      end Check;
   begin
      Check (One_Arg ("-k1,1"), "a b" & LF & "a a" & LF, "a a" & LF & "a b" & LF,
             "sort orders equal keys by the whole line as a last resort");
      Check (Two_Args ("-r", "-k1,1"), "a a" & LF & "a b" & LF, "a b" & LF & "a a" & LF,
             "sort reverses the last-resort comparison under -r");
      Check (Two_Args ("-s", "-k1,1"), "a b" & LF & "a a" & LF, "a b" & LF & "a a" & LF,
             "sort -s keeps equal keys in input order");
      Check (Three_Args ("-s", "-r", "-k1,1"), "b 1" & LF & "a 2" & LF & "b 3" & LF,
             "b 1" & LF & "b 3" & LF & "a 2" & LF,
             "sort -s -r keeps equal keys in input order");
      Check (Two_Args ("-u", "-r"), "a" & LF & "b" & LF & "a" & LF, "b" & LF & "a" & LF,
             "sort -u -r keeps one of each line");
      Check (Three_Args ("-u", "-r", "-k1,1"), "b 1" & LF & "a 2" & LF & "b 3" & LF,
             "b 1" & LF & "a 2" & LF,
             "sort -u -r keeps the first of lines with equal keys");
      Check (One_Arg ("-nu"), "1" & LF & "01" & LF, "1" & LF,
             "sort -nu treats numerically equal keys as duplicates");
      Check (One_Arg ("-n"), "1" & LF & "01" & LF, "01" & LF & "1" & LF,
             "sort -n orders numerically equal lines by bytes");
      Check (Two_Args ("-r", "-k2n"), "x 2" & LF & "x 10" & LF & "y 1" & LF,
             "y 1" & LF & "x 2" & LF & "x 10" & LF,
             "sort key modifiers override the global -r");
      Check (Two_Args ("-f", "-k1,1r"), "b" & LF & "A" & LF & "a" & LF & "B" & LF,
             "b" & LF & "a" & LF & "B" & LF & "A" & LF,
             "sort key modifiers override the global -f");
      Check (No_Args, "b" & LF & "B" & LF & "a" & LF & "A" & LF, "A" & LF & "B" & LF & "a" & LF & "b" & LF,
             "sort uses byte order in the C locale");
      Check (One_Arg ("-k1,1"), " b" & LF & "a" & LF, " b" & LF & "a" & LF,
             "sort keeps the leading blanks of a field without -t");
      Check (Two_Args ("-b", "-k1,1"), " b" & LF & "a" & LF, "a" & LF & " b" & LF,
             "sort -b skips the leading blanks of a field");
      Check (One_Arg ("-k1b,1"), " b" & LF & "a" & LF, "a" & LF & " b" & LF,
             "sort key modifier b skips the leading blanks of a field");
      Check (One_Arg ("-k2,2"), "x a" & LF & "x  b" & LF, "x  b" & LF & "x a" & LF,
             "sort counts the blanks before a later field as part of it");
      Check (Two_Args ("-b", "-k2,2"), "x  b" & LF & "x a" & LF, "x a" & LF & "x  b" & LF,
             "sort -b skips the blanks before a later field");
      Check (One_Arg ("-k1.2,1.2"), "yb" & LF & " az" & LF, " az" & LF & "yb" & LF,
             "sort counts key characters from the leading blanks of a field");
      Check (Two_Args ("-b", "-k1.2,1.2"), " az" & LF & "yb" & LF, "yb" & LF & " az" & LF,
             "sort -b counts key characters after the leading blanks of a field");

      Context.Initialize ("sort", Two_Args ("-cu", "-n"));
      Test_Contexts.Set_Standard_Input (Context, "1" & LF & "01" & LF);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -c -u -n rejects numerically equal adjacent keys");

      Context.Initialize ("sort", Three_Args ("-o", "/nonexistent-directory/sorted", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Error_Output (Context)
           = "sort: '/nonexistent-directory/sorted': cannot write file" & LF,
         "sort reports an -o file it cannot write");
   end Test_Sort_Ordering_Rules;
