with Ada.Directories;
with Ada.Strings.Fixed;
with AUnit.Assertions;
with Command_Tests.Surface_Smoke.Fixtures;
with Command_Tests.Surface_Smoke.Helpers;
with Hostkit.Fs;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Tee;
with Posix_Tools.Commands.Tr;
with Posix_Tools.Commands.Uniq;
with Posix_Tools.Commands.Xargs;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Signals;
with Test_Contexts;

package body Command_Tests.Surface_Smoke.Filters is
   use type Posix_Tools.Host_Adapters.Signals.Disposition;
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Surface_Smoke.Fixtures;
   use Command_Tests.Surface_Smoke.Helpers;

   procedure Test_Tee (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Ada.Directories.Create_Directory (Made);
      Context.Initialize ("tee", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "tee-data");
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "tee-data", "tee output");

      Write_File (Tee_Out, "old");
      Context.Initialize ("tee", Three_Args ("-ai", "--", Tee_Out));
      Test_Contexts.Set_Standard_Input (Context, "new");
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "new", "tee -ai stdout");
      Context.Initialize ("cat", One_Arg (Tee_Out));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "oldnew", "tee -a appends file");

      if Posix_Tools.Host_Adapters.Signals.Is_Supported (Posix_Tools.Host_Adapters.Signals.Interrupt) then
         declare
            Before : Posix_Tools.Host_Adapters.Signals.Disposition;
            After  : Posix_Tools.Host_Adapters.Signals.Disposition;
            Got_Before : constant Boolean :=
              Posix_Tools.Host_Adapters.Signals.Current_Disposition
                (Posix_Tools.Host_Adapters.Signals.Interrupt, Before);
         begin
            AUnit.Assertions.Assert (Got_Before, "tee -i can inspect interrupt disposition");
            Context.Initialize ("tee", Two_Args ("-i", "--"));
            Test_Contexts.Set_Standard_Input (Context, "signal-safe");
            Posix_Tools.Commands.Tee.Run (Context, Result);
            AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tee -i status");
            AUnit.Assertions.Assert
              (Posix_Tools.Host_Adapters.Signals.Current_Disposition
                 (Posix_Tools.Host_Adapters.Signals.Interrupt, After)
               and then After = Before,
               "tee -i restores interrupt disposition");
         end;
      end if;

      Context.Initialize ("tee", One_Arg (Made));
      Test_Contexts.Set_Standard_Input (Context, "blocked");
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "blocked"
         and then Ada.Strings.Fixed.Index (Test_Contexts.Error_Output (Context), Made) > 0,
         "tee reports failed file output");

      Context.Initialize ("tee", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "blocked");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tee reports standard-output failure");

      Context.Initialize ("tee", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 3);
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "abc",
         "tee streams readable prefix before input failure");

      Context.Initialize ("tee", One_Arg ("-z"));
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tee validates options before reading stdin");
   end Test_Tee;

   procedure Test_Tr (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("tr", Two_Args ("abc", "xyz"));
      Test_Contexts.Set_Standard_Input (Context, "cab");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zxy", "tr output");

      Context.Initialize ("tr", Two_Args ("a-c", "x-z"));
      Test_Contexts.Set_Standard_Input (Context, "cab");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zxy", "tr range output");

      Context.Initialize ("tr", Two_Args ("\n\t", "NL"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & Character'Val (9) & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "aNLb", "tr control escape output");

      Context.Initialize ("tr", Two_Args ("\\", "/"));
      Test_Contexts.Set_Standard_Input (Context, "a\b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a/b", "tr backslash escape output");

      Context.Initialize ("tr", Two_Args ("\101\102", "xy"));
      Test_Contexts.Set_Standard_Input (Context, "ABC");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xyC", "tr octal escape output");

      Context.Initialize ("tr", Two_Args ("\141-\143", "x-z"));
      Test_Contexts.Set_Standard_Input (Context, "cab");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zxy", "tr octal range output");

      Context.Initialize ("tr", Two_Args ("\011-\012", "TN"));
      Test_Contexts.Set_Standard_Input (Context, Character'Val (9) & Character'Val (10) & "x");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "TNx", "tr control range output");

      Context.Initialize ("tr", Two_Args ("-d", "\n"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "tr delete newline escape output");

      Context.Initialize ("tr", Two_Args ("[:lower:]", "[:upper:]"));
      Test_Contexts.Set_Standard_Input (Context, "a1z");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "A1Z", "tr lower upper class output");

      Context.Initialize ("tr", Two_Args ("-d", "[:digit:]"));
      Test_Contexts.Set_Standard_Input (Context, "a1b2");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "tr digit class delete output");

      Context.Initialize ("tr", Two_Args ("-d", "[:xdigit:]"));
      Test_Contexts.Set_Standard_Input (Context, "aFgZ19-");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "gZ-", "tr xdigit class delete output");

      Context.Initialize ("tr", Two_Args ("-d", "[:punct:]"));
      Test_Contexts.Set_Standard_Input (Context, "a,b.c!");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "tr punct class delete output");

      Context.Initialize ("tr", Two_Args ("-s", "[:blank:]"));
      Test_Contexts.Set_Standard_Input (Context, "a  " & Character'Val (9) & Character'Val (9) & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a " & Character'Val (9) & "b",
         "tr blank class squeeze output");

      Context.Initialize ("tr", Two_Args ("[:cntrl:]", "?"));
      Test_Contexts.Set_Standard_Input (Context, "a" & Character'Val (0) & Character'Val (127));
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a??", "tr cntrl class translate output");

      Context.Initialize ("tr", Two_Args ("-cd", "[:print:]"));
      Test_Contexts.Set_Standard_Input (Context, "a" & Character'Val (0) & " ");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a ", "tr print class complement output");

      Context.Initialize ("tr", Two_Args ("-d", "a-c"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "d", "tr delete range output");

      Context.Initialize ("tr", Two_Args ("-cd", "a-c"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ca", "tr delete complement output");

      Context.Initialize ("tr", Three_Args ("-c", "a-c", "X"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "caX", "tr complement translate output");

      Context.Initialize ("tr", Three_Args ("-c", "a-c", "XY"));
      Test_Contexts.Set_Standard_Input (Context, Character'Val (0) & "d");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "XY", "tr ordered complement translate output");

      Context.Initialize ("tr", Three_Args ("-C", "a-c", "X"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "caX", "tr uppercase complement translate output");

      Test_Contexts.Set_Locale (Context, "da");
      Context.Initialize ("tr", Three_Args ("-c", "a-c", "XYZ"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input (Context, "defA");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XYZZ",
         "tr locale collation orders complement translation");

      Context.Initialize ("tr", Two_Args ("-s", "a-c"));
      Test_Contexts.Set_Standard_Input (Context, "aaabbbdd");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abdd", "tr squeeze output");

      Context.Initialize ("tr", Three_Args ("-s", "a-c", "x"));
      Test_Contexts.Set_Standard_Input (Context, "abcccd");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xd", "tr translate squeeze output");

      Context.Initialize ("tr", Three_Args ("-ds", "a-c", "d"));
      Test_Contexts.Set_Standard_Input (Context, "abdddde");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "de", "tr delete squeeze output");

      Context.Initialize ("tr", Two_Args ("abc", "[x*3]"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xxx", "tr repeated set output");

      Context.Initialize ("tr", Two_Args ("abc", "[x*]"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xxx", "tr shorthand repeated set output");

      Context.Initialize ("tr", Two_Args ("a-i", "[x*010]y"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "xxxxxxxxy",
         "tr leading-zero repeat count is octal");

      Context.Initialize ("tr", Two_Args ("a", "[x*999999999999999999999999999999999999999]"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "[",
         "tr overflowing repeat count falls back to literal bracket");

      Context.Initialize ("tr", Three_Args ("-c", "a-c", "[z*]"));
      Test_Contexts.Set_Standard_Input (Context, Character'Val (0) & "d");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zz", "tr shorthand repeat covers complement domain");

      Context.Initialize ("tr", Two_Args ("abc", "[\n*2]"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = EOL & EOL & EOL,
         "tr repeated escaped set output");

      Context.Initialize ("tr", Two_Args ("[=a=][.b.]", "xy"));
      Test_Contexts.Set_Standard_Input (Context, "aba");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "xyx",
         "tr single-byte equivalence and collating output");

      Context.Initialize ("tr", Two_Args ("[=\n=]", "N"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "aNb", "tr escaped equivalence output");

      Context.Initialize ("tr", Two_Args ("[=a=]", "X"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "a" & Character'Val (16#C3#) & Character'Val (16#A1#) & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XXb",
         "tr locale equivalence translates accented UTF-8 characters");

      Context.Initialize ("tr", Two_Args ("[.ab.][=cd=]", "XY"));
      Test_Contexts.Set_Standard_Input (Context, "abcd");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XYYY",
         "tr multibyte identity bracket output");

      Context.Initialize ("tr", Two_Args ("[.ch.]", "X"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "chico");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XXiXo",
         "tr locale collating symbol expands as a multibyte element");

      Context.Initialize ("tr", Two_Args ("[.a\n.]", "XY"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL);
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XY",
         "tr escaped multibyte collating output");

      Context.Initialize ("tr", Two_Args ("abc", "xyz"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Output_Failure_After (Context, 1);
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tr output failure status");
   end Test_Tr;

   procedure Test_Uniq (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("uniq", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL, "uniq output");

      Context.Initialize ("uniq", One_Arg ("-c"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "      2 a" & EOL & "      1 b" & EOL,
         "uniq -c output");

      Context.Initialize ("uniq", One_Arg ("-d"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL, "uniq -d output");

      Context.Initialize ("uniq", One_Arg ("-u"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & EOL, "uniq -u output");

      Context.Initialize ("uniq", Two_Args ("-f", "1"));
      Test_Contexts.Set_Standard_Input (Context, "1 same" & EOL & "2 same" & EOL & "3 other" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1 same" & EOL & "3 other" & EOL,
         "uniq -f output");

      Context.Initialize ("uniq", Two_Args ("-f", "1"));
      Test_Contexts.Set_Standard_Input
        (Context,
         "1" & Character'Val (16#C2#) & Character'Val (16#A0#) & "same" & EOL
         & "2" & Character'Val (16#C2#) & Character'Val (16#A0#) & "same" & EOL
         & "3" & Character'Val (16#C2#) & Character'Val (16#A0#) & "other" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "1" & Character'Val (16#C2#) & Character'Val (16#A0#) & "same" & EOL
           & "3" & Character'Val (16#C2#) & Character'Val (16#A0#) & "other" & EOL,
         "uniq -f uses Unicode whitespace");

      Context.Initialize ("uniq", One_Arg ("-s1"));
      Test_Contexts.Set_Standard_Input (Context, "asame" & EOL & "bsame" & EOL & "cother" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "asame" & EOL & "cother" & EOL,
         "uniq -s output");

      Context.Initialize ("uniq", One_Arg ("-s1"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A6#) & "same" & EOL
         & Character'Val (16#C3#) & Character'Val (16#B8#) & "same" & EOL
         & Character'Val (16#C3#) & Character'Val (16#A5#) & "other" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C3#) & Character'Val (16#A6#) & "same" & EOL
           & Character'Val (16#C3#) & Character'Val (16#A5#) & "other" & EOL,
         "uniq -s skips UTF-8 characters");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input (Context, "Alpha" & EOL & "alpha" & EOL & "Beta" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "Alpha" & EOL & "Beta" & EOL,
         "uniq -i output");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#CE#) & Character'Val (16#A3#) & EOL
         & Character'Val (16#CF#) & Character'Val (16#83#) & EOL
         & Character'Val (16#D0#) & Character'Val (16#AF#) & EOL
         & Character'Val (16#D1#) & Character'Val (16#8F#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#CE#) & Character'Val (16#A3#) & EOL
           & Character'Val (16#D0#) & Character'Val (16#AF#) & EOL,
         "uniq -i folds UTF-8 Greek and Cyrillic case pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C4#) & Character'Val (16#80#) & EOL
         & Character'Val (16#C4#) & Character'Val (16#81#) & EOL
         & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
         & Character'Val (16#D5#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#83#) & Character'Val (16#90#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C4#) & Character'Val (16#80#) & EOL
           & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
           & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL,
         "uniq -i folds UTF-8 Latin Extended Armenian and Georgian pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C6#) & Character'Val (16#81#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#93#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#94#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#90#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#9B#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C6#) & Character'Val (16#81#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#90#) & EOL,
         "uniq -i folds UTF-8 Latin Extended-B pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL
         & Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#A8#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL,
         "uniq -i folds UTF-8 Deseret pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
         & Character'Val (16#EA#) & Character'Val (16#AD#) & Character'Val (16#B0#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BD#) & Character'Val (16#81#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
           & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL,
         "uniq -i folds UTF-8 Cherokee and Fullwidth Latin pairs");

      Context.Initialize ("uniq", One_Arg ("-ci"));
      Test_Contexts.Set_Standard_Input (Context, "Alpha" & EOL & "alpha" & EOL & "Beta" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "      2 Alpha" & EOL & "      1 Beta" & EOL,
         "uniq grouped -ci output");

      Context.Initialize ("uniq", One_Arg ("-c"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A5#) & EOL
         & Character'Val (16#E2#) & Character'Val (16#84#) & Character'Val (16#AB#) & EOL
         & "z" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "      2 " & Character'Val (16#C3#) & Character'Val (16#A5#) & EOL
           & "      1 z" & EOL,
         "uniq uses Danish locale collation equivalence");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "Ch" & EOL & "ch" & EOL & "d" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "Ch" & EOL & "d" & EOL,
         "uniq -i uses locale collation key after case folding");

      Context.Initialize ("uniq", Two_Args ("-i", "-s1"));
      Test_Contexts.Set_Standard_Input (Context, "xAlpha" & EOL & "yalpha" & EOL & "zBeta" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "xAlpha" & EOL & "zBeta" & EOL,
         "uniq -i -s output");

      Context.Initialize ("uniq", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL);
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "uniq output failure status");
   end Test_Uniq;

   procedure Test_Uniq_Output_Operand (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
      Ada.Directories.Create_Directory (Made);
      Remove_Any (Option_Dir);
      Ada.Directories.Create_Directory (Option_Dir);
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "x" & EOL);
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);
         Context.Initialize ("uniq", Two_Args ("plain", "-c"));
         Posix_Tools.Commands.Uniq.Run (Context, Result);
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Ada.Directories.Exists (Hostkit.Fs.Join (Option_Dir, "-c")),
         "uniq treats option-like words after first file operand as file operands");

      Context.Initialize ("cat", One_Arg (Hostkit.Fs.Join (Option_Dir, "-c")));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "x" & EOL,
         "uniq output operand receives filtered data");

      Context.Initialize ("uniq", Two_Args (Source, Made));
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "uniq reports output-file failure");
   end Test_Uniq_Output_Operand;

   procedure Test_Xargs (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b" & EOL, "xargs output");

      Context.Initialize ("xargs", Two_Args ("--", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b" & EOL, "xargs honors end-of-options");

      Context.Initialize ("xargs", Three_Args ("echo", "-n1", "fixed"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-n1 fixed a b" & EOL,
         "xargs stops option parsing after utility operand");

      Context.Initialize ("xargs", Two_Args ("-r", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "xargs -r skips empty input");

      Context.Initialize ("xargs", Two_Args ("--no-run-if-empty", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "   " & Character'Val (9));
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "xargs long no-run skips blank input");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a   b" & Character'Val (9) & "c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c" & EOL, "xargs collapses blanks");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a 'b c' ""d e""");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c d e" & EOL, "xargs quote grouping");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a 'b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects unmatched single quote");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a ""b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects unmatched double quote");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a\ b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c" & EOL, "xargs backslash grouping");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a\");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects trailing backslash");

      Context.Initialize ("xargs", Two_Args ("-n1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "'a b' c\ d");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL & "c d" & EOL,
         "xargs grouped operands batch as single items");

      Context.Initialize ("xargs", Three_Args ("-n", "2", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL & "c" & EOL,
         "xargs -n output");

      Context.Initialize ("xargs", Three_Args ("-s", "11", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "aa bb cc");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "aa bb" & EOL & "cc" & EOL,
         "xargs -s splits by composed command size");

      Context.Initialize ("xargs", Two_Args ("-s9", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "aa bb");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "aa" & EOL & "bb" & EOL,
         "xargs compact -s splits by composed command size");

      Context.Initialize ("xargs", Two_Args ("-t", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a b" & EOL
         and then Test_Contexts.Error_Output (Context) = "echo a b" & EOL,
         "xargs -t traces composed command");

      Context.Initialize ("xargs", Two_Args ("-t", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "xargs -t reports trace output failure");

      Context.Initialize ("xargs", Four_Args ("-x", "-s", "11", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "aa bb cc");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "xargs -x fails instead of splitting oversized batch");

      Context.Initialize ("xargs", Two_Args ("-s", "0"));
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects zero command size");

      Context.Initialize ("xargs", Four_Args ("-I", "{}", "echo", "file-{}"));
      Test_Contexts.Set_Standard_Input (Context, "one two" & EOL & "three" & EOL);
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file-one two" & EOL & "file-three" & EOL,
         "xargs -I replacement output");

      Context.Initialize ("xargs", Three_Args ("-I{}", "echo", "{}/suffix"));
      Test_Contexts.Set_Standard_Input (Context, "root" & EOL);
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "root/suffix" & EOL,
         "xargs compact -I replacement output");

      Context.Initialize ("xargs", One_Arg ("-I"));
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects missing -I replacement string");

      Context.Initialize ("xargs", Three_Args ("-E", "STOP", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b STOP c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL,
         "xargs -E output");

      Context.Initialize ("xargs", Five_Args ("-E", "STOP", "-n", "1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a STOP c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL,
         "xargs -E -n output");

      Context.Initialize ("xargs", Two_Args ("-0", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b" & Character'Val (0) & "c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c" & EOL, "xargs -0 output");

      Context.Initialize ("xargs", Four_Args ("-0", "-n", "1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b" & Character'Val (0) & "c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL & "c" & EOL,
         "xargs -0 -n output");

      Context.Initialize ("xargs", Two_Args ("-n1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL,
         "xargs compact -n output");

      Context.Initialize ("xargs", One_Arg ("false"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Xargs_Utility_Failed,
         "xargs classifies non-zero utility status");

      Context.Initialize ("xargs", One_Arg ("xargs-status-255"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Xargs_Utility_Requested_Stop,
         "xargs classifies utility status 255");

      Context.Initialize ("xargs", One_Arg ("xargs-cannot-invoke"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Cannot_Invoke,
         "xargs classifies utility status 126");

      Context.Initialize ("xargs", One_Arg ("missing-utility"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Not_Found,
         "xargs classifies missing utility");
   end Test_Xargs;

end Command_Tests.Surface_Smoke.Filters;
