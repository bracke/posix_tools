separate (Command_Tests.Surface_Smoke.Files)
   procedure Test_Stat (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
      Context.Initialize ("stat", One_Arg (Source));
      Posix_Tools.Commands.Stat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), "File: " & Source & EOL)
         and then Contains (Test_Contexts.Output (Context), "Size: 9" & EOL)
         and then Contains (Test_Contexts.Output (Context), "Type: regular file" & EOL)
         and then Contains (Test_Contexts.Output (Context), "Mode: "),
         "stat reports regular file metadata");

      Context.Initialize ("stat", Three_Args ("-c", "%n %s %F", Source));
      Posix_Tools.Commands.Stat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Source & " 9 regular file" & EOL,
         "stat supports custom format fields");

      Context.Initialize ("stat", Three_Args ("-c", "%x|%X|%y|%Y|%w|%W", Source));
      Posix_Tools.Commands.Stat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Contains (Test_Contexts.Output (Context), "%x")
         and then not Contains (Test_Contexts.Output (Context), "%X")
         and then not Contains (Test_Contexts.Output (Context), "%y")
         and then not Contains (Test_Contexts.Output (Context), "%Y")
         and then not Contains (Test_Contexts.Output (Context), "%w")
         and then not Contains (Test_Contexts.Output (Context), "%W"),
         "stat supports timestamp format fields");

      AUnit.Assertions.Assert
        (Hostkit.Metadata.Set_File_Times (Source, 1_577_934_245, 1_577_934_245), "stat fixture times");
      Context.Initialize ("stat", Three_Args ("-c", "%Y", Source));
      Posix_Tools.Commands.Stat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1577934245" & EOL,
         "stat counts epoch seconds from the epoch in UTC");
   end Test_Stat;
