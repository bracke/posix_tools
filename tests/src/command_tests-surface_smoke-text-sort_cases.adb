with Ada.Directories;
with AUnit.Assertions;
with Command_Tests.Surface_Smoke.Fixtures;
with Command_Tests.Surface_Smoke.Helpers;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Sort;
with Test_Contexts;

package body Command_Tests.Surface_Smoke.Text.Sort_Cases is
   use Command_Tests.Surface_Smoke.Fixtures;
   use Command_Tests.Surface_Smoke.Helpers;

   procedure Test_Sort (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
      Ada.Directories.Create_Directory (Made);
      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL, "sort output");

      Context.Initialize ("sort", Two_Args ("-ru", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & EOL & "a" & EOL, "sort -ru output");
   end Test_Sort;

   procedure Test_Sort_Folding (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("sort", Two_Args ("-f", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "A" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "A" & EOL & "b" & EOL, "sort -f output");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#85#) & EOL
         & Character'Val (16#C3#) & Character'Val (16#A5#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#C3#) & Character'Val (16#85#) & EOL,
         "sort -f folds UTF-8 Latin-1 case pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#CE#) & Character'Val (16#91#) & EOL
         & Character'Val (16#CE#) & Character'Val (16#B1#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#CE#) & Character'Val (16#91#) & EOL,
         "sort -f folds UTF-8 Greek case pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#D0#) & Character'Val (16#AF#) & EOL
         & Character'Val (16#D1#) & Character'Val (16#8F#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#D0#) & Character'Val (16#AF#) & EOL,
         "sort -f folds UTF-8 Cyrillic case pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C4#) & Character'Val (16#80#) & EOL
         & Character'Val (16#C4#) & Character'Val (16#81#) & EOL
         & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
         & Character'Val (16#D5#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#83#) & Character'Val (16#90#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C4#) & Character'Val (16#80#) & EOL
           & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
           & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL,
         "sort -f folds UTF-8 Latin Extended Armenian and Georgian pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C6#) & Character'Val (16#81#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#93#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#94#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#90#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#9B#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C6#) & Character'Val (16#81#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#90#) & EOL,
         "sort -f folds UTF-8 Latin Extended-B pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL
         & Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#A8#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL,
         "sort -f folds UTF-8 Deseret pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
         & Character'Val (16#EA#) & Character'Val (16#AD#) & Character'Val (16#B0#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BD#) & Character'Val (16#81#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
           & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL,
         "sort -f folds UTF-8 Cherokee and Fullwidth Latin pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#9F#) & EOL
         & "ss" & EOL
         & Character'Val (16#EF#) & Character'Val (16#AC#) & Character'Val (16#83#) & EOL
         & "ffi" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#EF#) & Character'Val (16#AC#) & Character'Val (16#83#) & EOL
           & Character'Val (16#C3#) & Character'Val (16#9F#) & EOL,
         "sort -f folds Unicode multi-code-point case mappings");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#E2#) & Character'Val (16#84#) & Character'Val (16#AA#) & EOL
         & "k" & EOL
         & Character'Val (16#CF#) & Character'Val (16#82#) & EOL
         & Character'Val (16#CF#) & Character'Val (16#83#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#E2#) & Character'Val (16#84#) & Character'Val (16#AA#) & EOL
           & Character'Val (16#CF#) & Character'Val (16#82#) & EOL,
         "sort -f folds Unicode compatibility and final-sigma mappings");
   end Test_Sort_Folding;

end Command_Tests.Surface_Smoke.Text.Sort_Cases;
