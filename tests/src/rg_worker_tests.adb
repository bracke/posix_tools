with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Rg_Worker_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;

   type Run_Outcome is record
      Output : Unbounded_String;
      Errors : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Run_Rg (Args : Posix_Tools.Arguments.Vector) return Run_Outcome;

   function Run_Rg (Args : Posix_Tools.Arguments.Vector) return Run_Outcome is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Parallel_Search (T : in out Fixture) is
      pragma Unreferenced (T);
      ESC  : constant Character := Character'Val (16#1B#);
      LF   : constant Character := ASCII.LF;
      Root : constant String := Test_Support.Work_Path ("rg-workers");
      Other_Root : constant String := Test_Support.Work_Path ("rg-workers-other");
      A    : constant String := Root & "/a.txt";
      B    : constant String := Root & "/b.txt";
      C    : constant String := Root & "/c.txt";
      D    : constant String := Other_Root & "/d.txt";
      Binary : constant String := Other_Root & "/binary.dat";
   begin
      Test_Support.Delete_If_Exists (Root);
      Test_Support.Delete_If_Exists (Other_Root);
      Ada.Directories.Create_Path (Root);
      Ada.Directories.Create_Path (Other_Root);
      Test_Support.Write_File (A, "needle a" & LF & "other" & LF);
      Test_Support.Write_File (B, "needle b" & LF);
      Test_Support.Write_File (C, "needle c" & LF);
      Test_Support.Write_File (D, "needle d" & LF);
      Test_Support.Write_File (Binary, ASCII.NUL & "needle binary" & LF);

      declare
         Parallel : constant Run_Outcome := Run_Rg (["-j4", "-n", "needle", Root]);
         Automatic : constant Run_Outcome := Run_Rg (["--debug", "-j0", "needle", Root]);
         Sorted : constant Run_Outcome :=
           Run_Rg (["--debug", "-j4", "--sort", "path", "needle", Root]);
         Json : constant Run_Outcome :=
           Run_Rg (["--json", "--threads=4", "needle", Root]);
         Colored : constant Run_Outcome :=
           Run_Rg
             (["--color", "always", "--colors", "match:fg:0,128,255", "-j4", "needle", Root]);
         Quiet : constant Run_Outcome := Run_Rg (["-j4", "-q", "needle", Root]);
         Invalid : constant Run_Outcome :=
           Run_Rg (["--threads=bad", "needle", Root]);
         Explicit : constant Run_Outcome :=
           Run_Rg (["--debug", "-j4", "needle", C, A, B]);
         Roots : constant Run_Outcome :=
           Run_Rg (["--debug", "-j4", "needle", Other_Root, Root]);
         Explicit_Binary : constant Run_Outcome :=
           Run_Rg (["-j4", "needle", A, Binary]);
         Sorted_Text : constant String := To_String (Sorted.Output);
         Explicit_Text : constant String := To_String (Explicit.Output);
         Roots_Text : constant String := To_String (Roots.Output);
      begin
         AUnit.Assertions.Assert
           (Parallel.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Parallel.Errors) = ""
            and then Test_Support.Occurrences (To_String (Parallel.Output), "needle") = 3
            and then Test_Support.Occurrences (To_String (Parallel.Output), A) = 1
            and then Test_Support.Occurrences (To_String (Parallel.Output), B) = 1
            and then Test_Support.Occurrences (To_String (Parallel.Output), C) = 1,
            "four native workers search each discovered file exactly once");
         AUnit.Assertions.Assert
           (Automatic.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Automatic.Errors), "rg::workers|using")
            and then not Test_Support.Contains (To_String (Automatic.Errors), "using 0 worker"),
            "zero selects a nonzero automatic worker count");
         AUnit.Assertions.Assert
           (Sorted.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains
              (To_String (Sorted.Errors), "using 1 worker thread(s)")
            and then Ada.Strings.Fixed.Index (Sorted_Text, A) > 0
            and then Ada.Strings.Fixed.Index (Sorted_Text, A)
              < Ada.Strings.Fixed.Index (Sorted_Text, B)
            and then Ada.Strings.Fixed.Index (Sorted_Text, B)
              < Ada.Strings.Fixed.Index (Sorted_Text, C),
            "sorting forces one worker and preserves the requested order");
         AUnit.Assertions.Assert
           (Json.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Occurrences
              (To_String (Json.Output), """type"":""begin""") = 3
            and then Test_Support.Occurrences
              (To_String (Json.Output), """type"":""match""") = 3
            and then Test_Support.Occurrences
              (To_String (Json.Output), """type"":""end""") = 3
            and then Test_Support.Occurrences
              (To_String (Json.Output), """type"":""summary""") = 1,
            "parallel JSON emits complete per-file event groups and one summary");
         AUnit.Assertions.Assert
           (Colored.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Occurrences
              (To_String (Colored.Output), ESC & "[38;2;0;128;255m") = 3,
            "parallel color rendering emits one intact truecolor prefix per match");
         AUnit.Assertions.Assert
           (Quiet.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Quiet.Output) = "",
            "quiet parallel search cancels queued work after success");
         AUnit.Assertions.Assert
           (Invalid.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains
              (To_String (Invalid.Errors), "invalid value for --threads"),
            "invalid worker counts are rejected explicitly");
         AUnit.Assertions.Assert
           (Explicit.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Occurrences
              (To_String (Explicit.Errors), "rg::workers|using 4 worker thread(s)") = 1
            and then Ada.Strings.Fixed.Index (Explicit_Text, C) > 0
            and then Ada.Strings.Fixed.Index (Explicit_Text, C)
              < Ada.Strings.Fixed.Index (Explicit_Text, A)
            and then Ada.Strings.Fixed.Index (Explicit_Text, A)
              < Ada.Strings.Fixed.Index (Explicit_Text, B),
            "explicit files share one worker pool and retain operand-order output");
         AUnit.Assertions.Assert
           (Roots.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Occurrences
              (To_String (Roots.Errors), "rg::workers|using 4 worker thread(s)") = 1
            and then Ada.Strings.Fixed.Index (Roots_Text, D) > 0
            and then Ada.Strings.Fixed.Index (Roots_Text, D)
              < Ada.Strings.Fixed.Index (Roots_Text, A),
            "independent roots share one worker pool and retain root order");
         AUnit.Assertions.Assert
           (Explicit_Binary.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Explicit_Binary.Output), Binary),
            "explicit files retain binary-search defaults in a mixed worker batch");
      end;

      for Iteration in 1 .. 8 loop
         declare
            Result : constant Run_Outcome := Run_Rg (["-j4", "-c", "needle", Root]);
         begin
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success
               and then Test_Support.Occurrences (To_String (Result.Output), ":1" & LF) = 3,
               "repeated parallel count run" & Positive'Image (Iteration) & " remains complete");
         end;
      end loop;

      declare
         Stress_Root : constant String := Root & "/stress";
         Payload     : constant String (1 .. 16 * 1024) := [others => 'a'];
      begin
         Ada.Directories.Create_Path (Stress_Root);
         for Index in 1 .. 96 loop
            Test_Support.Write_File
              (Stress_Root & "/item-"
               & Ada.Strings.Fixed.Trim (Positive'Image (Index), Ada.Strings.Both)
               & ".txt",
               "needle" & LF & Payload & LF);
         end loop;

         for Iteration in 1 .. 12 loop
            declare
               Result : constant Run_Outcome :=
                 Run_Rg (["-j8", "-c", "needle", Stress_Root]);
            begin
               AUnit.Assertions.Assert
                 (Result.Status = Posix_Tools.Exit_Status.Success
                  and then Test_Support.Occurrences (To_String (Result.Output), ":1" & LF) = 96
                  and then To_String (Result.Errors) = "",
                  "large-directory worker stress run"
                  & Positive'Image (Iteration) & " remains race-free");
            end;
         end loop;

         declare
            Cancelled : constant Run_Outcome :=
              Run_Rg (["-j8", "-q", "needle|a+a+a+a+a+a+a+a+z", A, Stress_Root]);
         begin
            AUnit.Assertions.Assert
              (Cancelled.Status = Posix_Tools.Exit_Status.Success
               and then To_String (Cancelled.Output) = ""
               and then To_String (Cancelled.Errors) = "",
               "quiet cancellation stops active parallel regular expressions cleanly");
         end;
      end;

      Test_Support.Delete_If_Exists (Root);
      Test_Support.Delete_If_Exists (Other_Root);
   end Test_Parallel_Search;
end Rg_Worker_Tests;
