with AUnit.Assertions;
with Command_Tests.Surface_Smoke.Fixtures;
with Command_Tests.Surface_Smoke.Helpers;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Cksum;
with Posix_Tools.Commands.Cmp;
with Posix_Tools.Commands.Comm;
with Posix_Tools.Commands.Cut;
with Posix_Tools.Commands.Od;
with Posix_Tools.Commands.Paste;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Sha256sum;
with Posix_Tools.Commands.Split;
with Posix_Tools.Exit_Status;
with Test_Contexts;

package body Command_Tests.Surface_Smoke.Data is
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Surface_Smoke.Fixtures;
   use Command_Tests.Surface_Smoke.Helpers;

   procedure Test_Cksum (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Cksum_File, "abc");
      Context.Initialize ("cksum", One_Arg (Cksum_File));
      Posix_Tools.Commands.Cksum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), " 3 " & Cksum_File),
         "cksum prints checksum length and operand");

      Context.Initialize ("cksum", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Cksum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1219131554 3" & EOL,
         "cksum reads implicit standard input");

      Context.Initialize ("cksum", One_Arg ("--"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Cksum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1219131554 3" & EOL,
         "cksum treats a sole -- as end-of-options before implicit standard input");
   end Test_Cksum;

   procedure Test_Cmp (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Cmp_First, "same" & EOL);
      Write_File (Cmp_Second, "same" & EOL);
      Context.Initialize ("cmp", Two_Args (Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "cmp accepts equal files quietly");

      Write_File (Cmp_Second, "sage" & EOL);
      Context.Initialize ("cmp", Two_Args (Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Output (Context), "differ"),
         "cmp reports the first difference");

      Write_File (Cmp_First, "abc");
      Write_File (Cmp_Second, "axd");
      Context.Initialize ("cmp", Three_Args ("-l", Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "2 142 170" & EOL & "3 143 144" & EOL,
         "cmp -l lists all differing byte values in octal");

      Context.Initialize ("cmp", Four_Args ("-l", "-s", Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "cmp -s suppresses cmp -l output");

      Context.Initialize ("cmp", Four_Args ("-s", "--", Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "cmp accepts -- after -s and stays silent");

      Write_File (Cmp_First, "ab" & EOL & "cd" & EOL);
      Write_File (Cmp_Second, "ab" & EOL & "cx" & EOL);
      Context.Initialize ("cmp", Two_Args (Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Output (Context), "byte 5, line 2"),
         "cmp reports the line containing the first differing byte");

      Write_File (Cmp_First, "short");
      Write_File (Cmp_Second, "shorter");
      Context.Initialize ("cmp", Two_Args (Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Output (Context), "EOF on " & Cmp_First),
         "cmp reports EOF on the shorter file");
   end Test_Cmp;

   procedure Test_Comm (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Comm_First, "a" & EOL & "b" & EOL);
      Write_File (Comm_Second, "b" & EOL & "c" & EOL);
      Context.Initialize ("comm", Two_Args (Comm_First, Comm_Second));
      Posix_Tools.Commands.Comm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL
           & Character'Val (9) & Character'Val (9) & "b" & EOL
           & Character'Val (9) & "c" & EOL,
         "comm merges sorted files into three columns");

      Context.Initialize ("comm", Three_Args ("-12", Comm_First, Comm_Second));
      Posix_Tools.Commands.Comm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "b" & EOL,
         "comm suppression options leave only common lines");

      Context.Initialize ("comm", Three_Args ("--", Comm_First, Comm_Second));
      Posix_Tools.Commands.Comm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL
           & Character'Val (9) & Character'Val (9) & "b" & EOL
           & Character'Val (9) & "c" & EOL,
         "comm honors end-of-options before operands");
   end Test_Comm;

   procedure Test_Cut (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Cut_File, "abcd" & EOL & "wxyz" & EOL);
      Context.Initialize ("cut", Three_Args ("-b", "2-3", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "bc" & EOL & "xy" & EOL,
         "cut selects byte ranges");

      Context.Initialize ("cut", Three_Args ("-b", "1 4", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ad" & EOL & "wz" & EOL,
         "cut accepts blank-separated list entries");

      Context.Initialize ("cut", Four_Args ("-n", "-b", "1-2", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab" & EOL & "wx" & EOL,
         "cut accepts -n with byte mode");

      Context.Initialize ("cut", Three_Args ("-b", "999999999999999999999999999999", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "cut rejects overflowing list number");

      Context.Initialize ("cut", Three_Args ("-n", "-c", "1"));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "cut rejects -n outside byte mode");

      Context.Initialize ("cut", Five_Args ("-b", "1", "-c", "2", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "multiple list options"),
         "cut rejects multiple list options");

      Context.Initialize ("cut", Five_Args ("-b", "1", "-d", ",", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "invalid field option"),
         "cut rejects field delimiter option outside field mode");

      Context.Initialize ("cut", Three_Args ("-s", "-b", "1"));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "invalid field option"),
         "cut rejects field suppression option outside field mode");

      Write_File (Cut_File, "a,b,c" & EOL);
      Context.Initialize ("cut", Five_Args ("-f", "2", "-d", ",", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "b" & EOL,
         "cut selects delimited fields");

      Context.Initialize ("cut", Four_Args ("-f", "2", "-d,", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "b" & EOL,
         "cut accepts an attached delimiter option argument");

      Context.Initialize ("cut", Two_Args ("-f", "2"));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "cut reads standard input when only a list option is supplied");

      Context.Initialize ("cut", Three_Args ("-f", "2", "-d"));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-d'"),
         "cut rejects a missing delimiter argument");
   end Test_Cut;

   procedure Test_Od (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Od_File, "A");
      Context.Initialize ("od", One_Arg (Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), "0000000 000101")
         and then Contains (Test_Contexts.Output (Context), "0000001"),
         "od emits octal byte dump");

      Context.Initialize ("od", Two_Args ("-An", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = " 000101" & EOL,
         "od -An suppresses address output");

      Context.Initialize ("od", Two_Args ("-Ax", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 000101" & EOL & "0000001" & EOL,
         "od -Ax emits hexadecimal address output");

      Context.Initialize ("od", Three_Args ("-A", "d", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0 000101" & EOL & "1" & EOL,
         "od accepts a separate decimal address-base argument");

      Context.Initialize ("od", One_Arg ("-A"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-A'"),
         "od rejects a missing address-base argument");

      Context.Initialize ("od", Two_Args ("-A", "bad"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "od rejects an invalid address base");

      Write_File (Od_File, "ABCDEF");
      Context.Initialize ("od", Five_Args ("-j", "2", "-N", "3", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000002 042103 000105" & EOL & "0000005" & EOL,
         "od skips and limits input bytes");

      Context.Initialize ("od", Three_Args ("-j0x2", "-N03", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000002 042103 000105" & EOL & "0000005" & EOL,
         "od accepts attached hexadecimal skip and octal count");

      Context.Initialize ("od", Three_Args ("-N", "0", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000" & EOL,
         "od accepts a zero byte limit");

      Write_File (Od_File, String'(1 .. 512 => 'x') & "AB");
      Context.Initialize ("od", Two_Args ("-j1b", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0001000 041101" & EOL & "0001002" & EOL,
         "od supports block suffix skip arguments");

      Context.Initialize ("od", Two_Args ("-j1k", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "od rejects skips beyond input");

      Context.Initialize ("od", One_Arg ("-j"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-j'"),
         "od rejects a missing skip argument");

      Context.Initialize ("od", Two_Args ("-N", "0x"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "od rejects malformed count arguments");

      Write_File (Od_File, "ABCDEF");
      Context.Initialize ("od", Two_Args ("-tx1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 41 42 43 44 45 46" & EOL & "0000006" & EOL,
         "od supports attached hexadecimal byte type strings");

      Write_File (Od_File, String'(1 .. 32 => 'A'));
      Context.Initialize ("od", Two_Args ("-tx1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "0000000 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41" & EOL
           & "*" & EOL
           & "0000040" & EOL,
         "od suppresses duplicate output blocks by default");

      Context.Initialize ("od", Three_Args ("-v", "-tx1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "0000000 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41" & EOL
           & "0000020 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41" & EOL
           & "0000040" & EOL,
         "od -v emits duplicate output blocks");

      Write_File (Od_File, "ABCDEF");
      Context.Initialize ("od", Three_Args ("-t", "u1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 65 66 67 68 69 70" & EOL & "0000006" & EOL,
         "od supports separate unsigned byte type strings");

      Context.Initialize ("od", Two_Args ("-tx2", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 4241 4443 4645" & EOL & "0000006" & EOL,
         "od supports two-byte hexadecimal type strings");

      Context.Initialize ("od", Two_Args ("-td2", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 16961 17475 17989" & EOL & "0000006" & EOL,
         "od supports two-byte decimal type strings");

      Write_File (Od_File, Character'Val (255) & Character'Val (255));
      Context.Initialize ("od", Two_Args ("-td2", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 -1" & EOL & "0000002" & EOL,
         "od supports signed multi-byte type strings");

      Context.Initialize ("od", Two_Args ("-s", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 -1" & EOL & "0000002" & EOL,
         "od supports signed decimal shorthand");

      Context.Initialize ("od", Two_Args ("-d", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 65535" & EOL & "0000002" & EOL,
         "od supports unsigned decimal shorthand");

      Write_File (Od_File, Character'Val (0) & Character'Val (0) & Character'Val (128) & Character'Val (63));
      Context.Initialize ("od", Two_Args ("-tf4", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000  1.00000E+00" & EOL & "0000004" & EOL,
         "od supports single-precision floating type strings");

      Write_File
        (Od_File,
         Character'Val (0) & Character'Val (0) & Character'Val (0) & Character'Val (0)
         & Character'Val (0) & Character'Val (0) & Character'Val (240) & Character'Val (63));
      Context.Initialize ("od", Two_Args ("-tfD", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000  1.00000000000000E+00" & EOL & "0000010" & EOL,
         "od supports double-precision floating type strings");

      Write_File (Od_File, "A" & Character'Val (10) & Character'Val (0));
      Context.Initialize ("od", Two_Args ("-tc", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000   A  \\n  \\0" & EOL & "0000003" & EOL,
         "od supports character byte type strings");

      Context.Initialize ("od", Two_Args ("-ta", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000   A  nl nul" & EOL & "0000003" & EOL,
         "od supports named character type strings");

      Write_File (Od_File, "AB");
      Context.Initialize ("od", Five_Args ("-t", "x1", "-t", "c", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 41 42" & EOL & "   A   B" & EOL & "0000002" & EOL,
         "od supports multiple type-string output lines");

      Context.Initialize ("od", Two_Args ("-t", "f1"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "od rejects unsupported type strings");

      Context.Initialize ("od", Two_Args ("-t", "x999999999999999999999999999999"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "od rejects overflowing type sizes");
   end Test_Od;

   procedure Test_Paste (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Paste_First, "a" & EOL & "b" & EOL);
      Write_File (Paste_Second, "1" & EOL & "2" & EOL);
      Context.Initialize ("paste", Two_Args (Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & Character'Val (9) & "1" & EOL
           & "b" & Character'Val (9) & "2" & EOL,
         "paste merges lines with tabs");

      Context.Initialize ("paste", Three_Args ("--", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & Character'Val (9) & "1" & EOL
           & "b" & Character'Val (9) & "2" & EOL,
         "paste honors end-of-options before file operands");

      Context.Initialize ("paste", Four_Args ("-d", "|", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a|1" & EOL & "b|2" & EOL,
         "paste accepts a separate delimiter list");

      Context.Initialize ("paste", Three_Args ("-d,", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a,1" & EOL & "b,2" & EOL,
         "paste accepts an attached delimiter list");

      Context.Initialize ("paste", Three_Args ("-d\0", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a1" & EOL & "b2" & EOL,
         "paste delimiter list supports backslash-zero as an empty delimiter");

      Context.Initialize ("paste", Four_Args ("-d", "\n", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL & "1" & EOL & "b" & EOL & "2" & EOL,
         "paste delimiter list supports newline escape");

      Context.Initialize ("paste", Three_Args ("-s", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & Character'Val (9) & "b" & EOL
           & "1" & Character'Val (9) & "2" & EOL,
         "paste serial mode combines each file separately");

      Context.Initialize ("paste", One_Arg ("-d"));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-d'"),
         "paste rejects a missing delimiter list");
   end Test_Paste;

   procedure Test_Sha256sum (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
      Context.Initialize ("sha256sum", One_Arg (Source));
      Posix_Tools.Commands.Sha256sum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "31f096ed11381d8885e6bb572b98782840325a88e582dc576a039b6564ca9c77  " & Source & EOL,
         "sha256sum prints known file digest and operand");

      Write_File
        (Cksum_File,
         "31f096ed11381d8885e6bb572b98782840325a88e582dc576a039b6564ca9c77  " & Source & EOL);
      Context.Initialize ("sha256sum", Two_Args ("-c", Cksum_File));
      Posix_Tools.Commands.Sha256sum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Source & ": OK" & EOL,
         "sha256sum verifies checksum files");

      Context.Initialize ("sha256sum", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Sha256sum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" & EOL,
         "sha256sum reads implicit standard input");

      Context.Initialize ("sha256sum", No_Args);
      Test_Contexts.Set_Standard_Input (Context, Large_Hash_Input);
      Posix_Tools.Commands.Sha256sum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "42e8bc96b8eec8c4e5d503483ba0cb843ce95243c8ca8575ffc69cd25d12c61c" & EOL,
         "sha256sum streams input larger than one chunk");
   end Test_Sha256sum;

   procedure Test_Split (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Split_Input, "a" & EOL & "b" & EOL & "c" & EOL);
      Context.Initialize ("split", Four_Args ("-l", "2", Split_Input, Split_Prefix));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "split status");
      Context.Initialize ("cat", One_Arg (Split_Prefix & "aa"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL, "split first file");
      Context.Initialize ("cat", One_Arg (Split_Prefix & "ab"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "c" & EOL, "split second file");

      Context.Initialize ("split", Six_Args ("-a", "3", "-l", "1", Split_Input, Split_Long_Prefix));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "split -a status");
      Context.Initialize ("cat", One_Arg (Split_Long_Prefix & "aaa"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL, "split -a first file");
      Context.Initialize ("cat", One_Arg (Split_Long_Prefix & "aac"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "c" & EOL, "split -a third file");

      Context.Initialize ("split", One_Arg ("-a"));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-a'"),
         "split rejects a missing suffix length");

      Context.Initialize ("split", Two_Args ("-a", "0"));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "split rejects a zero suffix length");
   end Test_Split;

end Command_Tests.Surface_Smoke.Data;
