separate (Command_Tests.Output_Failure_Tests)

   procedure Test_Command_Verbose_Output_Failures (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Source  : constant String := Fixture_Path ("verbose-source.txt");
      Target  : constant String := Fixture_Path ("verbose-target.txt");
      Link    : constant String := Fixture_Path ("verbose-link.txt");
      Moved   : constant String := Fixture_Path ("verbose-moved.txt");
      Removed : constant String := Fixture_Path ("verbose-removed.txt");

      procedure Remove_Any (Path : String) is
      begin
         if Hostkit.Fs.Is_Link (Path) then
            AUnit.Assertions.Assert (Hostkit.Fs.Delete_Link (Path), "cleanup link failed for " & Path);
         elsif Ada.Directories.Exists (Path) then
            if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
               Ada.Directories.Delete_Tree (Path);
            else
               Ada.Directories.Delete_File (Path);
            end if;
         end if;
      end Remove_Any;
   begin
      Remove_Any (Source);
      Remove_Any (Target);
      Remove_Any (Link);
      Remove_Any (Moved);
      Remove_Any (Removed);

      Write_File (Source, "copy");
      Context.Initialize ("cp", Three_Args ("-v", Source, Target));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cp -v reports stdout failure");

      Write_File (Source, "link");
      Remove_Any (Link);
      Context.Initialize ("ln", Three_Args ("-v", Source, Link));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "ln -v reports stdout failure");

      Write_File (Source, "move");
      Remove_Any (Moved);
      Context.Initialize ("mv", Three_Args ("-v", Source, Moved));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "mv -v reports stdout failure");

      Write_File (Removed, "remove");
      Context.Initialize ("rm", Two_Args ("-v", Removed));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "rm -v reports stdout failure");

      Remove_Any (Source);
      Remove_Any (Target);
      Remove_Any (Link);
      Remove_Any (Moved);
      Remove_Any (Removed);
   end Test_Command_Verbose_Output_Failures;
