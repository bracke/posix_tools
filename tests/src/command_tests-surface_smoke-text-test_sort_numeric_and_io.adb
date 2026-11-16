separate (Command_Tests.Surface_Smoke.Text)
   procedure Test_Sort_Numeric_And_IO (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
      Ada.Directories.Create_Directory (Made);
      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "10 ten" & EOL & " 2 two" & EOL & "-1 minus" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-1 minus" & EOL & " 2 two" & EOL & "10 ten" & EOL,
         "sort -n output");

      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "2.50 two" & EOL & "-1.25 minus" & EOL & "2.05 low" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-1.25 minus" & EOL & "2.05 low" & EOL & "2.50 two" & EOL,
         "sort -n decimal output");

      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context, "2,50 two" & EOL & "-1,25 minus" & EOL & "2,05 low" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-1,25 minus" & EOL & "2,05 low" & EOL & "2,50 two" & EOL,
         "sort -n uses locale decimal separator");

      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         "1e3 high" & EOL
         & "2.5e-1 low" & EOL
         & "-1e2 minus" & EOL
         & "3 middle" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
         "-1e2 minus" & EOL
         & "2.5e-1 low" & EOL
         & "3 middle" & EOL
         & "1e3 high" & EOL,
         "sort -n exponent output");

      Context.Initialize ("sort", Two_Args ("-ns", "-"));
      Test_Contexts.Set_Standard_Input (Context, "2 z" & EOL & "2 a" & EOL & "1 one" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1 one" & EOL & "2 z" & EOL & "2 a" & EOL,
         "sort -ns preserves equal numeric input order");

      Context.Initialize ("sort", Two_Args ("-ub", "-"));
      Test_Contexts.Set_Standard_Input (Context, " apple" & EOL & "  apple" & EOL & "banana" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = " apple" & EOL & "banana" & EOL,
         "sort -ub output");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "sort -c accepts ordered input");

      Context.Initialize ("sort", Two_Args ("-cn", "-"));
      Test_Contexts.Set_Standard_Input (Context, "1.5" & EOL & "1.25" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -cn rejects decimal unordered input");

      Context.Initialize ("sort", Two_Args ("-cn", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input (Context, "1,5" & EOL & "1,25" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -cn uses locale decimal separator");

      Context.Initialize ("sort", Two_Args ("-cns", "-"));
      Test_Contexts.Set_Standard_Input (Context, "2 z" & EOL & "2 a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "sort -cns accepts stable equal numeric input order");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -c rejects unordered input");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "disorder: 'a'"),
         "sort -c says which line is out of order");

      Context.Initialize ("sort", Two_Args ("-C", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Error_Output (Context) = "",
         "sort -C rejects unordered input silently");

      Context.Initialize ("sort", Three_Args ("-c", Paste_First, Paste_Second));
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "extra operand"),
         "sort -c checks one input only");

      Write_File (Paste_First, "b");
      Write_File (Paste_Second, "a" & EOL);
      Context.Initialize ("sort", Two_Args (Paste_First, Paste_Second));
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL,
         "sort keeps a file without a final newline apart from the next");

      Context.Initialize ("sort", One_Arg ("-nk2"));
      Test_Contexts.Set_Standard_Input (Context, "x 10" & EOL & "y 9" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "y 9" & EOL & "x 10" & EOL,
         "sort takes a key attached behind grouped flags");

      Context.Initialize ("sort", Two_Args ("-rt:", "-k2"));
      Test_Contexts.Set_Standard_Input (Context, "a:1" & EOL & "b:2" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "b:2" & EOL & "a:1" & EOL,
         "sort takes a separator attached behind grouped flags");

      AUnit.Assertions.Assert
        (Posix_Tools.Commands.Text_Helpers.Folding.Folded_Sort_Text
           ("A" & Character'Val (16#C4#) & Character'Val (16#B0#) & Character'Val (16#C4#) & Character'Val (16#80#))
         = "ai" & Character'Val (16#CC#) & Character'Val (16#87#) & Character'Val (16#C4#) & Character'Val (16#81#),
         "case folding takes U+0130 to i and a dot above, and U+0100 to U+0101");

      Context.Initialize ("sort", Two_Args ("-Cr", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "sort -Cr accepts reverse ordered input");

      Context.Initialize ("sort", Two_Args ("-cu", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -cu rejects duplicates");

      Context.Initialize ("sort", Three_Args ("-o", Sort_Out, Source));
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Ada.Directories.Exists (Sort_Out), "sort -o output file");
      Context.Initialize ("cat", One_Arg (Sort_Out));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "copy-data" & EOL,
         "sort -o writes sorted file data");

      Context.Initialize ("sort", Three_Args ("-o", Made, Source));
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -o reports output-file failure");

      Remove_Any (Option_Dir);
      Ada.Directories.Create_Directory (Option_Dir);
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "b" & EOL);
      Write_File (Hostkit.Fs.Join (Option_Dir, "-r"), "a" & EOL);
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);
         Context.Initialize ("sort", Two_Args ("plain", "-r"));
         Posix_Tools.Commands.Sort.Run (Context, Result);
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Test_Support.Restore_Directory_Safely (Original_Directory);
            raise;
      end;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL,
         "sort treats option-like words after first file operand as file operands");
   end Test_Sort_Numeric_And_IO;
