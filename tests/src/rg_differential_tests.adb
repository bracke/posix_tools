with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Project_Tools.Processes;
with Test_Contexts;
with Test_Support;

package body Rg_Differential_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;

   type Run_Outcome is record
      Output : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Run_Rg
     (Args  : Posix_Tools.Arguments.Vector;
      Input : String) return Run_Outcome
   is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Test_Contexts.Set_Standard_Input (Context, Input);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Reference_Differential (T : in out Fixture) is
      pragma Unreferenced (T);
      package Processes renames Project_Tools.Processes;

      Reference : constant String := Processes.Locate_Command ("rg");

      procedure Check
        (Name           : String;
         Native_Args    : Posix_Tools.Arguments.Vector;
         Reference_Args : Processes.Argument_Vectors.Vector;
         Input          : String;
         Restores_Final_LF : Boolean := True)
      is
         Native : constant Run_Outcome := Run_Rg (Native_Args, Input);
         Other  : constant Processes.Captured_Process :=
           Processes.Capture_Command (Reference, Reference_Args, Input);
      begin
         AUnit.Assertions.Assert
           (Integer (Native.Status) = Other.Status,
            "ripgrep 15.2.0 differential status: " & Name);
         --  Project_Tools' capture helper removes one final LF.
         AUnit.Assertions.Assert
           (To_String (Native.Output) =
              To_String (Other.Output)
                & (if Restores_Final_LF then String'(1 => ASCII.LF) else ""),
            "ripgrep 15.2.0 differential output: " & Name);
      end Check;
   begin
      declare
         Context : Test_Contexts.Capturing_Context;
         Result  : Posix_Tools.Commands.Results.Result;
      begin
         Context.Initialize ("rg", Posix_Tools.Arguments.Empty);
         Test_Contexts.Set_Locale (Context, "da");
         Posix_Tools.Commands.Rg.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains
              (Test_Contexts.Error_Output (Context), "et søgemønster er påkrævet"),
            "rg option diagnostics use the project message catalog");
      end;

      --  The ordinary suite remains portable. If a reference is installed,
      --  comparisons run only for the deliberately pinned release.
      if Reference = "" then
         return;
      end if;
      declare
         Version : constant Processes.Captured_Process :=
           Processes.Capture_Command
             (Reference,
              Processes.Arguments ([Processes.Argument ("--version")]));
      begin
         if not Test_Support.Contains (To_String (Version.Output), "ripgrep 15.2.0") then
            return;
         end if;
      end;

      Check
        ("line number",
         ["-n", "needle"],
         Processes.Arguments ([Processes.Argument ("-n"), Processes.Argument ("needle")]),
         "hay" & ASCII.LF & "needle" & ASCII.LF);
      Check
        ("fixed insensitive",
         ["-F", "-i", "A.B"],
         Processes.Arguments
           ([Processes.Argument ("-F"), Processes.Argument ("-i"), Processes.Argument ("A.B")]),
         "a.b" & ASCII.LF & "axb" & ASCII.LF);
      Check
        ("only matching",
         ["-o", "ab+"],
         Processes.Arguments ([Processes.Argument ("-o"), Processes.Argument ("ab+")]),
         "xabb ab" & ASCII.LF);
      Check
        ("inverted",
         ["-v", "skip"],
         Processes.Arguments ([Processes.Argument ("-v"), Processes.Argument ("skip")]),
         "keep" & ASCII.LF & "skip" & ASCII.LF);
      Check
        ("count",
         ["-c", "x"],
         Processes.Arguments ([Processes.Argument ("-c"), Processes.Argument ("x")]),
         "x" & ASCII.LF & "none" & ASCII.LF & "xx" & ASCII.LF);

      Check
        ("multiple patterns",
         ["-e", "cat", "-e", "dog"],
         Processes.Arguments
           ([Processes.Argument ("-e"), Processes.Argument ("cat"),
             Processes.Argument ("-e"), Processes.Argument ("dog")]),
         "cat" & ASCII.LF & "bird" & ASCII.LF & "dog" & ASCII.LF);
      Check
        ("whole word",
         ["-w", "cat"],
         Processes.Arguments ([Processes.Argument ("-w"), Processes.Argument ("cat")]),
         "cat" & ASCII.LF & "scatter" & ASCII.LF);
      Check
        ("maximum count",
         ["-m", "1", "x"],
         Processes.Arguments
           ([Processes.Argument ("-m"), Processes.Argument ("1"), Processes.Argument ("x")]),
         "x first" & ASCII.LF & "x second" & ASCII.LF);
      Check
        ("context",
         ["-n", "-C", "1", "hit"],
         Processes.Arguments
           ([Processes.Argument ("-n"), Processes.Argument ("-C"),
             Processes.Argument ("1"), Processes.Argument ("hit")]),
         "before" & ASCII.LF & "hit" & ASCII.LF & "after" & ASCII.LF & "far" & ASCII.LF);
      Check
        ("count matches",
         ["--count-matches", "ab"],
         Processes.Arguments
           ([Processes.Argument ("--count-matches"), Processes.Argument ("ab")]),
         "ab xx ab" & ASCII.LF);
      Check
        ("replacement",
         ["--replace", "<$1>", "(ab)"],
         Processes.Arguments
           ([Processes.Argument ("--replace"), Processes.Argument ("<$1>"),
             Processes.Argument ("(ab)")]),
         "xx ab yy" & ASCII.LF);
      Check
        ("multiline dotall",
         ["-U", "--multiline-dotall", "-o", "a.*b"],
         Processes.Arguments
           ([Processes.Argument ("-U"), Processes.Argument ("--multiline-dotall"),
             Processes.Argument ("-o"), Processes.Argument ("a.*b")]),
         "a" & ASCII.LF & "middle" & ASCII.LF & "b" & ASCII.LF);
      Check
        ("NUL data",
         ["--null-data", "hit"],
         Processes.Arguments
           ([Processes.Argument ("--null-data"), Processes.Argument ("hit")]),
         "miss" & ASCII.NUL & "hit" & ASCII.NUL,
         Restores_Final_LF => False);
      Check
        ("nested byte mode",
         ["-o", "A(?-u:.)(?u:B)"],
         Processes.Arguments
           ([Processes.Argument ("-o"), Processes.Argument ("A(?-u:.)(?u:B)")]),
         "A" & Character'Val (16#FF#) & "B" & ASCII.LF);

      declare
         Root : constant String := Test_Support.Work_Path ("rg-reference-differential");
         Encoded : constant String := Root & "/encoded.txt";
         Ada_File : constant String := Root & "/keep.adb";
      begin
         Test_Support.Delete_If_Exists (Root);
         Ada.Directories.Create_Path (Root);
         Test_Support.Write_File (Root & "/.gitignore", "*.tmp" & ASCII.LF);
         Test_Support.Write_File (Root & "/.ignore", "!keep.tmp" & ASCII.LF);
         Test_Support.Write_File (Root & "/.rgignore", "drop.adb" & ASCII.LF);
         Test_Support.Write_File (Root & "/keep.tmp", "hit kept" & ASCII.LF);
         Test_Support.Write_File (Root & "/drop.tmp", "hit dropped" & ASCII.LF);
         Test_Support.Write_File (Ada_File, "hit ada" & ASCII.LF);
         Test_Support.Write_File (Root & "/drop.adb", "hit ignored" & ASCII.LF);
         Test_Support.Write_File
           (Encoded, "caf" & Character'Val (16#E9#) & " hit" & ASCII.LF);

         Check
           ("hierarchical ignore discovery",
            ["--sort", "path", "--files", Root],
            Processes.Arguments
              ([Processes.Argument ("--sort"), Processes.Argument ("path"),
                Processes.Argument ("--files"), Processes.Argument (Root)]),
            "");
         Check
           ("glob and type traversal",
            ["--sort", "path", "-g", "*.adb", "-t", "ada", "hit", Root],
            Processes.Arguments
              ([Processes.Argument ("--sort"), Processes.Argument ("path"),
                Processes.Argument ("-g"), Processes.Argument ("*.adb"),
                Processes.Argument ("-t"), Processes.Argument ("ada"),
                Processes.Argument ("hit"), Processes.Argument (Root)]),
            "");
         Check
           ("Windows-1252 decoding",
            ["--encoding", "windows-1252", "caf" & Character'Val (16#C3#) & Character'Val (16#A9#), Encoded],
            Processes.Arguments
              ([Processes.Argument ("--encoding"), Processes.Argument ("windows-1252"),
                Processes.Argument ("caf" & Character'Val (16#C3#) & Character'Val (16#A9#)),
                Processes.Argument (Encoded)]),
            "");
         Test_Support.Delete_If_Exists (Root);
      end;
   end Test_Reference_Differential;
end Rg_Differential_Tests;
