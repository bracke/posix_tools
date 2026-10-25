with Ada.Directories;
with AUnit.Assertions;
with Command_Tests.Surface_Smoke.Fixtures;
with Command_Tests.Surface_Smoke.Helpers;
with Hostkit.Fs;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Dd;
with Posix_Tools.Commands.Printf;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Sort;
with Posix_Tools.Exit_Status;
with Test_Contexts;

package body Command_Tests.Surface_Smoke.Text is
   use type Ada.Directories.File_Size;
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Surface_Smoke.Fixtures;
   use Command_Tests.Surface_Smoke.Helpers;

   procedure Test_Dd (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("dd", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "abcdef"
         and then Test_Contexts.Error_Output (Context) = "0+1 records in" & EOL & "0+1 records out" & EOL,
         "dd default block size records");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=3"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "abc"
         and then Test_Contexts.Error_Output (Context) = "3+0 records in" & EOL & "3+0 records out" & EOL,
         "dd count output and records");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=0"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "0+0 records in" & EOL & "0+0 records out" & EOL,
         "dd count zero copies no records");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Error_Output (Context) = "",
         "dd reports standard-output failure");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=1b"));
      Test_Contexts.Set_Standard_Input (Context, String'(1 .. 520 => 'x'));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context)'Length = 512, "dd count b suffix output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=1K"));
      Test_Contexts.Set_Standard_Input (Context, String'(1 .. 1_030 => 'x'));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context)'Length = 1_024, "dd count K suffix output");

      Context.Initialize ("dd", Two_Args ("count=1", "bs=1M"));
      Test_Contexts.Set_Standard_Input (Context, "x");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "x", "dd M suffix block size output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=3w"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd count w suffix output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=3c"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "dd count c suffix output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=2x3"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd count x multiplier output");

      Context.Initialize ("dd", Three_Args ("bs=1", "count=2", "count=4"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcd", "dd later count operand wins");

      Context.Initialize ("dd", Two_Args ("bs=2", "count=2"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcd", "dd block count output");

      Context.Initialize ("dd", Two_Args ("bs=2x3", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd block x multiplier output");

      Context.Initialize ("dd", Three_Args ("files=1", "bs=1", "count=3"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "dd files operand output");

      Context.Initialize ("dd", One_Arg ("files=0"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects zero files operand");

      Context.Initialize ("dd", Two_Args ("ibs=3", "count=2"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd ibs count output");

      Context.Initialize ("dd", Three_Args ("bs=2", "skip=1", "count=2"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "cdef", "dd skip output");

      Context.Initialize ("dd", Three_Args ("ibs=3", "skip=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "dd ibs skip output");

      Context.Initialize ("dd", Three_Args ("ibs=3", "iseek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "dd iseek alias output");

      Context.Initialize ("dd", Three_Args ("bs=2", "seek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (0) & Character'Val (0) & "ab",
         "dd seek output");

      Context.Initialize ("dd", Four_Args ("ibs=1", "obs=3", "seek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (0) & Character'Val (0) & Character'Val (0) & "a",
         "dd obs seek output");

      Context.Initialize ("dd", Four_Args ("ibs=1", "obs=3", "oseek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (0) & Character'Val (0) & Character'Val (0) & "a",
         "dd oseek alias output");

      Context.Initialize ("dd", One_Arg ("conv=ucase"));
      Test_Contexts.Set_Standard_Input (Context, "aBz 12");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ABZ 12", "dd conv=ucase output");

      Context.Initialize ("dd", One_Arg ("conv=ucase,lcase"));
      Test_Contexts.Set_Standard_Input (Context, "aBz 12");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abz 12", "dd later conversion wins output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=ebcdic"));
      Test_Contexts.Set_Standard_Input (Context, "Az09");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (193) & Character'Val (169) & Character'Val (240) & Character'Val (249),
         "dd conv=ebcdic byte table output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=ascii"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (193) & Character'Val (169) & Character'Val (240) & Character'Val (249));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "Az09" & EOL, "dd conv=ascii byte table output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=ibm"));
      Test_Contexts.Set_Standard_Input (Context, "AZ");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (193) & Character'Val (233) & Character'Val (64) & Character'Val (64),
         "dd conv=ibm byte table output");

      Context.Initialize ("dd", One_Arg ("conv=ascii"));
      Test_Contexts.Set_Standard_Input (Context, "abcd");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd conv=ascii requires cbs");

      Context.Initialize ("dd", One_Arg ("conv=swab"));
      Test_Contexts.Set_Standard_Input (Context, "abcde");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "badce", "dd conv=swab odd output");

      Context.Initialize ("dd", One_Arg ("conv=noerror"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "abc",
         "dd conv=noerror normal input output");

      Context.Initialize ("dd", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "dd input failure without noerror status");

      Context.Initialize ("dd", One_Arg ("conv=noerror"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab",
         "dd conv=noerror retains readable prefix");

      Context.Initialize ("dd", Two_Args ("ibs=4", "conv=noerror"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab"
         and then Contains (Test_Contexts.Error_Output (Context), "cannot read file")
         and then Contains (Test_Contexts.Error_Output (Context), "0+1 records in"),
         "dd conv=noerror omits failed unsynchronized block tail");

      Context.Initialize ("dd", Two_Args ("ibs=4", "conv=noerror,sync"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab" & Character'Val (0) & Character'Val (0)
         and then Contains (Test_Contexts.Error_Output (Context), "cannot read file")
         and then Contains (Test_Contexts.Error_Output (Context), "0+1 records in")
         and then Contains (Test_Contexts.Error_Output (Context), "0+1 records out"),
         "dd conv=noerror sync pads failed input block");

      Context.Initialize ("dd", Two_Args ("ibs=4", "conv=sync"));
      Test_Contexts.Set_Standard_Input (Context, "ab");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "ab" & Character'Val (0) & Character'Val (0),
         "dd conv=sync pads short block");

      Context.Initialize ("dd", Three_Args ("ibs=4", "count=1", "conv=sync,swab"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "ba" & Character'Val (0) & "c",
         "dd conv=sync swab output");

      Context.Initialize ("dd", Three_Args ("bs=1", "conv=swab,ucase", "count=4"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "BADC", "dd conv=swab ucase output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=block"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "bcdef" & EOL & "xy");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a   " & "bcde" & "xy  ", "dd conv=block output");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "1 truncated record"),
         "dd conv=block reports singular truncated record");

      Context.Initialize ("dd", Two_Args ("cbs=2", "conv=block"));
      Test_Contexts.Set_Standard_Input (Context, "abc" & EOL & "def" & EOL);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "ab" & "de"
         and then Contains (Test_Contexts.Error_Output (Context), "2 truncated records"),
         "dd conv=block reports plural truncated records");

      Context.Initialize ("dd", Three_Args ("ibs=4", "cbs=4", "conv=sync,block"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a   ",
         "dd conv=sync block pads with spaces");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=unblock"));
      Test_Contexts.Set_Standard_Input (Context, "a   bcde");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "bcde" & EOL, "dd conv=unblock output");

      Context.Initialize ("dd", Three_Args ("ibs=4", "cbs=4", "conv=sync,unblock"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL,
         "dd conv=sync unblock pads with spaces");

      Context.Initialize ("dd", One_Arg ("conv=block"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd conv=block requires cbs");

      Write_File (Target, "abcdef");
      Context.Initialize ("dd", Four_Args ("of=" & Target, "bs=1", "count=2", "conv=notrunc"));
      Test_Contexts.Set_Standard_Input (Context, "XY");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "XYcdef", "dd conv=notrunc preserves tail");

      Write_File (Target, "abcdef");
      Context.Initialize ("dd", Five_Args ("of=" & Target, "bs=2", "seek=1", "count=1", "conv=notrunc"));
      Test_Contexts.Set_Standard_Input (Context, "XY");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abXYef", "dd conv=notrunc honors seek offset");

      Context.Initialize ("dd", Four_Args ("of=" & Target, "obs=1M", "seek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "Z");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Size (Target) = Ada.Directories.File_Size (1_048_577),
         "dd output file seek uses file offset");

      Context.Initialize ("dd", One_Arg ("bs=1q"));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects unsupported numeric suffix");

      Context.Initialize ("dd", One_Arg ("bs=999999999999999999999999999999G"));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects overflow numeric suffix");

      Context.Initialize ("dd", One_Arg ("bs=2x"));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects empty multiplier factor");
   end Test_Dd;

   procedure Test_Printf (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("printf", Two_Args ("%s\n", "value"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "value" & EOL, "printf output");

      Context.Initialize ("printf", Three_Args ("%s\n", "one", "two"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "one" & EOL & "two" & EOL,
         "printf format reuse output");

      Context.Initialize ("printf", Two_Args ("%d\n", "42"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "42" & EOL, "printf decimal output");

      Context.Initialize ("printf", Three_Args ("%d\n", "+0007", "-0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7" & EOL & "0" & EOL,
         "printf canonical decimal output");

      Context.Initialize ("printf", Three_Args ("%i\n", "+0007", "-0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7" & EOL & "0" & EOL,
         "printf signed integer output");

      Context.Initialize ("printf", Three_Args ("%u\n", "+0007", "0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7" & EOL & "0" & EOL,
         "printf unsigned decimal output");

      Context.Initialize ("printf", Four_Args ("%o:%x:%X", "15", "255", "255"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "17:ff:FF",
         "printf unsigned base output");

      Context.Initialize ("printf", Two_Args ("%b", "a\nb"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b", "printf percent b newline");

      Context.Initialize ("printf", Two_Args ("%b", "\101\102"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "AB", "printf percent b octal");

      Context.Initialize ("printf", Three_Args ("%5s:%3d\n", "x", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "    x:  7" & EOL,
         "printf minimum width output");

      Context.Initialize ("printf", Three_Args ("%-5s:%-3d\n", "x", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "x    :7  " & EOL,
         "printf left-justified width output");

      Context.Initialize ("printf", Two_Args ("%.3s", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "printf string precision output");

      Context.Initialize ("printf", Two_Args ("%5.3s", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  abc", "printf width precision output");

      Context.Initialize ("printf", Two_Args ("%-5.3s", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc  ", "printf left width precision output");

      Context.Initialize ("printf", Three_Args ("%*s", "5", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "    x", "printf star width output");

      Context.Initialize ("printf", Three_Args ("%*s", "-5", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "x    ", "printf negative star width output");

      Context.Initialize ("printf", Three_Args ("%.*s", "3", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "printf star precision output");

      Context.Initialize ("printf", Four_Args ("%*.*d", "6", "4", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  0007", "printf star width precision output");

      Context.Initialize ("printf", Three_Args ("%.4d:%.4d", "7", "-7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0007:-0007",
         "printf decimal precision output");

      Context.Initialize ("printf", Three_Args ("%6.4d:%-6.4d", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  0007:0007  ",
         "printf decimal width precision output");

      Context.Initialize ("printf", Three_Args ("%6.4u:%-6.4u", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  0007:0007  ",
         "printf unsigned width precision output");

      Context.Initialize ("printf", Three_Args ("%6.4x:%-6.4o", "255", "9"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  00ff:0011  ",
         "printf base width precision output");

      Context.Initialize ("printf", Four_Args ("%#o:%#x:%#X", "9", "255", "255"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "011:0xff:0XFF",
         "printf alternate base output");

      Context.Initialize ("printf", Four_Args ("%#o:%#x:%#X", "0", "0", "0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0:0:0",
         "printf alternate zero output");

      Context.Initialize ("printf", Two_Args ("%#08x", "255"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0x0000ff",
         "printf alternate zero-padded hex output");

      Context.Initialize ("printf", Four_Args ("%+d:% d:%+ d", "7", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+7: 7:+7",
         "printf signed flag output");

      Context.Initialize ("printf", Three_Args ("%f:%.2f", "1.5", "-2.345"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.500000:-2.35",
         "printf fixed floating output");

      Context.Initialize ("printf", Three_Args ("%8.2f:%-8.1f", "1.5", "2"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "    1.50:2.0     ",
         "printf fixed floating width output");

      Context.Initialize ("printf", Three_Args ("%+07.2f:% 5.1f", "1.5", "2"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+001.50:  2.0",
         "printf fixed floating flags output");

      Context.Initialize ("printf", Three_Args ("%e:%.2E", "1.5", "-0.01234"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.500000e+00:-1.23E-02",
         "printf scientific floating output");

      Context.Initialize ("printf", Two_Args ("%.2e", "1.2e3"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.20e+03",
         "printf scientific exponent input output");

      Context.Initialize ("printf", Two_Args ("%+010.2e", "12.34"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+01.23e+01",
         "printf scientific floating flags output");

      Context.Initialize ("printf", Four_Args ("%g:%g:%G", "1234", "0.0000123", "0.0000123"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1234:1.23e-05:1.23E-05",
         "printf general floating output");

      Context.Initialize ("printf", Three_Args ("%#.4g:%8.3g", "12.3", "12.3"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "12.30:    12.3",
         "printf general floating flags output");

      Context.Initialize ("printf", Three_Args ("%+i:%.4i", "7", "-7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+7:-0007",
         "printf signed integer flag precision output");

      Context.Initialize ("printf", Three_Args ("%f:%.2e", "1.5", "-12.3"));
      Test_Contexts.Set_Environment_Value (Context, "LC_NUMERIC", "da");
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1,500000:-1,23e+01",
         "printf uses LC_NUMERIC decimal separator");

      Context.Initialize ("printf", Three_Args ("%f:%.2e", "1.5", "-12.3"));
      Test_Contexts.Set_Environment_Value (Context, "LC_NUMERIC", "da");
      Test_Contexts.Set_Environment_Value (Context, "LC_ALL", "en");
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.500000:-1.23e+01",
         "printf LC_ALL overrides LC_NUMERIC");

      Context.Initialize ("printf", Four_Args ("%05d:%05d:%05u", "7", "-7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "00007:-0007:00007",
         "printf zero padding output");

      Context.Initialize ("printf", Three_Args ("%-05d:%05.3d", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7    :  007",
         "printf flag precedence output");

      Context.Initialize ("printf", Two_Args ("%5.3b", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  abc", "printf percent b width precision");

      Context.Initialize ("printf", Three_Args ("%b%s", "a\cignored", "later"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a", "printf percent b c stops output");

      Context.Initialize ("printf", Two_Args ("%.0d", "0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "printf zero decimal precision output");

      Context.Initialize ("printf", One_Arg ("%d:%u:%x:%f:%.1g"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0:0:0:0.000000:0",
         "printf missing numeric operands default to zero");

      Context.Initialize ("printf", Two_Args ("%*d:%.*s", "3"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  0:",
         "printf missing star and numeric operands default deterministically");

      Context.Initialize ("printf", Two_Args ("%s", "blocked"));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "printf reports standard-output failure");

      --  XCU printf: a numeric argument is a C constant, and an unsigned
      --  conversion of a negative one wraps as strtoumax gives it.
      Context.Initialize ("printf", Two_Args ("%u", "-1"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "18446744073709551615",
         "printf unsigned conversion of a negative argument wraps");

      Context.Initialize ("printf", Three_Args ("%*s|", "bad", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "x|"
         and then Test_Contexts.Error_Output (Context) = "printf: 'bad': expected a numeric value" & EOL,
         "printf invalid star width is diagnosed and taken as zero");

      Context.Initialize ("printf", Three_Args ("%*s", "9223372036854775808", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf overflowing star width status");

      Context.Initialize ("printf", Two_Args ("%999999999999999999999999999999999999999s", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf overflowing literal width status");

      Context.Initialize ("printf", Two_Args ("%.999999999999999999999999999999999999999s", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf overflowing literal precision status");

      Context.Initialize ("printf", Two_Args ("%x", "-1"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ffffffffffffffff",
         "printf hexadecimal conversion of a negative argument wraps");

      --  An argument that is not a number is diagnosed, written as zero,
      --  and makes the exit status 1 while printf goes on.
      Context.Initialize ("printf", Three_Args ("%d|%s", "abc", "next"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "0|next"
         and then Test_Contexts.Error_Output (Context) = "printf: 'abc': expected a numeric value" & EOL,
         "printf invalid decimal is diagnosed and printing continues");

      Context.Initialize ("printf", Two_Args ("%f", "abc"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "0.000000",
         "printf invalid float is diagnosed and written as zero");

      Context.Initialize ("printf", Two_Args ("%f", "999999999999999999999999999999999999999.0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "printf fixed diagnoses an overflowing whole part");

      Context.Initialize ("printf", Two_Args ("%.20f", "0.99999999999999999999"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "printf fixed diagnoses an overflowing fraction part");

      Context.Initialize ("printf", Two_Args ("%e", "1e999999999999999999999999999999999999999"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "printf scientific diagnoses an overflowing exponent");

      Context.Initialize ("printf", Two_Args ("%g", "1e999999999999999999999999999999999999999"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "printf general diagnoses an overflowing exponent");

      Context.Initialize ("printf", Two_Args ("%i", "abc"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "printf invalid signed integer status");

      Context.Initialize ("printf", Three_Args ("%c", "alpha", "beta"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "printf character reuse output");

      Context.Initialize ("printf", Three_Args ("%3c:%-3c", "alpha", "beta"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  a:b  ", "printf character width output");

      Context.Initialize ("printf", One_Arg ("%3c"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "   ", "printf missing character width output");

      Context.Initialize ("printf", One_Arg ("%%\t\\"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "%" & Character'Val (9) & "\",
         "printf escapes");

      Context.Initialize ("printf", One_Arg ("\a\b\f\v"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "" & Character'Val (7) & Character'Val (8) & Character'Val (12) & Character'Val (11),
         "printf control escapes");

      --  In the format \ddd is one to three octal digits, so \0101 is
      --  \010 followed by '1' (XBD File Format Notation).
      Context.Initialize ("printf", One_Arg ("\0101\0102"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (8) & "1" & Character'Val (8) & "2",
         "printf format octal escapes take at most three digits");
   end Test_Printf;

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

      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A5#) & EOL
         & "z" & EOL
         & Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
         & Character'Val (16#C3#) & Character'Val (16#B8#) & EOL
         & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "a" & EOL
           & "z" & EOL
           & Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
           & Character'Val (16#C3#) & Character'Val (16#B8#) & EOL
           & Character'Val (16#C3#) & Character'Val (16#A5#) & EOL,
         "sort uses Danish locale collation order");

      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "d" & EOL & "ch" & EOL & "c" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "c" & EOL & "ch" & EOL & "d" & EOL,
         "sort uses Spanish multibyte collation symbols");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         "z" & EOL
         & Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
         & Character'Val (16#C3#) & Character'Val (16#B8#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "sort -c uses Danish locale collation order");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
         & "z" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -c rejects Danish locale unordered input");

      Context.Initialize ("sort", Two_Args ("-b", "-"));
      Test_Contexts.Set_Standard_Input (Context, "  b" & EOL & " a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = " a" & EOL & "  b" & EOL, "sort -b output");

      Context.Initialize ("sort", Two_Args ("-bf", "-"));
      Test_Contexts.Set_Standard_Input (Context, "  beta" & EOL & " Alpha" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = " Alpha" & EOL & "  beta" & EOL,
         "sort grouped -bf output");

      Context.Initialize ("sort", Two_Args ("-d", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a#2" & EOL & "a 10" & EOL & "a!1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 10" & EOL & "a!1" & EOL & "a#2" & EOL,
         "sort -d output");

      Context.Initialize ("sort", Two_Args ("-cd", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a#2" & EOL & "a!1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -cd rejects dictionary unordered input");

      Context.Initialize ("sort", Two_Args ("-i", "-"));
      Test_Contexts.Set_Standard_Input
        (Context, "a" & Character'Val (1) & "2" & EOL & "a1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a1" & EOL & "a" & Character'Val (1) & "2" & EOL,
         "sort -i output");

      Context.Initialize ("sort", Two_Args ("-ci", "-"));
      Test_Contexts.Set_Standard_Input
        (Context, "a" & Character'Val (1) & "2" & EOL & "a1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -ci rejects ignore-nonprinting unordered input");

      Context.Initialize ("sort", Two_Args ("-k2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b 2" & EOL & "a 1" & EOL & "c 3" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 1" & EOL & "b 2" & EOL & "c 3" & EOL,
         "sort -k attached field key output");

      Context.Initialize ("sort", Two_Args ("-k2", "-"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "x d" & EOL & "x ch" & EOL & "x c" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "x c" & EOL & "x ch" & EOL & "x d" & EOL,
         "sort -k uses locale collation order");

      Context.Initialize ("sort", Four_Args ("-t", ":", "-k", "2"));
      Test_Contexts.Set_Standard_Input (Context, "x:b" & EOL & "z:a" & EOL & "y:c" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "z:a" & EOL & "x:b" & EOL & "y:c" & EOL,
         "sort -t -k separated field key output");

      Context.Initialize ("sort", Two_Args ("-k2,2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 2 z" & EOL & "b 1 y" & EOL & "c 3 x" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b 1 y" & EOL & "a 2 z" & EOL & "c 3 x" & EOL,
         "sort -k start end field key output");

      Context.Initialize ("sort", Two_Args ("-k1.2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "x3" & EOL & "z1" & EOL & "y2" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "z1" & EOL & "y2" & EOL & "x3" & EOL,
         "sort -k start character key output");

      --  Without -t the blank before field 2 belongs to it, so its digit is
      --  the field's third character.
      Context.Initialize ("sort", Three_Args ("-k", "2.3,2.3", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a b3" & EOL & "b a1" & EOL & "c c2" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b a1" & EOL & "c c2" & EOL & "a b3" & EOL,
         "sort -k separated character range output");

      Context.Initialize ("sort", Three_Args ("-n", "-k2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 10" & EOL & "b 2" & EOL & "c -1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "c -1" & EOL & "b 2" & EOL & "a 10" & EOL,
         "sort -n -k field key output");

      Context.Initialize ("sort", Two_Args ("-k2n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 10" & EOL & "b 2" & EOL & "c -1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "c -1" & EOL & "b 2" & EOL & "a 10" & EOL,
         "sort -k numeric modifier output");

      Context.Initialize ("sort", Two_Args ("-k1f", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "B" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL & "B" & EOL,
         "sort -k fold-case modifier output");

      Context.Initialize ("sort", Two_Args ("-k1d", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a#2" & EOL & "a 10" & EOL & "a!1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 10" & EOL & "a!1" & EOL & "a#2" & EOL,
         "sort -k dictionary modifier output");

      Context.Initialize ("sort", Two_Args ("-k1i", "-"));
      Test_Contexts.Set_Standard_Input
        (Context, "a" & Character'Val (1) & "2" & EOL & "a1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a1" & EOL & "a" & Character'Val (1) & "2" & EOL,
         "sort -k ignore-nonprinting modifier output");

      Context.Initialize ("sort", Four_Args ("-t", ":", "-k", "2b"));
      Test_Contexts.Set_Standard_Input (Context, "a:  b" & EOL & "b: a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b: a" & EOL & "a:  b" & EOL,
         "sort -k ignore-leading-blanks modifier output");

      Context.Initialize ("sort", Two_Args ("-k1r", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & EOL & "a" & EOL,
         "sort -k reverse modifier output");

      Context.Initialize ("sort", Three_Args ("-k1,1", "-k2n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b 2" & EOL & "b 1" & EOL & "a 3" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 3" & EOL & "b 1" & EOL & "b 2" & EOL,
         "sort multiple keys output");

      Context.Initialize ("sort", Three_Args ("-k1,1", "-k2nr", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 1" & EOL & "a 3" & EOL & "b 2" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 3" & EOL & "a 1" & EOL & "b 2" & EOL,
         "sort multiple keys reverse numeric output");

      Context.Initialize ("sort", Two_Args ("-m", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "c" & EOL & "b" & EOL & "d" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL & "c" & EOL & "d" & EOL,
         "sort -m output");

      Context.Initialize ("sort", Two_Args ("-k0", "-"));
      Test_Contexts.Set_Standard_Input (Context, "data" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sort rejects zero key field");

      Context.Initialize ("sort", Two_Args ("-k999999999999999999999999999999", "-"));
      Test_Contexts.Set_Standard_Input (Context, "data" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sort rejects overflowing key field");

      Context.Initialize ("sort", Two_Args ("-k3,2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "data" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sort rejects decreasing key field range");

      Context.Initialize ("sort", Two_Args ("-k2.3,2.2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "data" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sort rejects decreasing key character range");

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
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL,
         "sort treats option-like words after first file operand as file operands");
   end Test_Sort;

end Command_Tests.Surface_Smoke.Text;
