with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Rg_Stats_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;

   type Run_Outcome is record
      Output : Unbounded_String;
      Errors : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Run_Rg (Args : Posix_Tools.Arguments.Vector) return Run_Outcome;
   function Natural_Image (Value : Natural) return String;

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

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

   procedure Test_Statistics (T : in out Fixture) is
      pragma Unreferenced (T);
      LF    : constant Character := ASCII.LF;
      First : constant String := Test_Support.Work_Path ("rg-stats-a.txt");
      Second : constant String := Test_Support.Work_Path ("rg-stats-b.txt");
      Multi : constant String := Test_Support.Work_Path ("rg-stats-multi.txt");
   begin
      Test_Support.Write_File (First, "hit one" & LF & "no" & LF & "hit hit" & LF);
      Test_Support.Write_File (Second, "none" & LF);
      Test_Support.Write_File (Multi, "a" & LF & "hit" & LF & "hit" & LF & "z" & LF);

      declare
         Normal : constant Run_Outcome := Run_Rg (["--stats", "hit", First, Second]);
         Counted : constant Run_Outcome := Run_Rg (["--stats", "-c", "hit", First, Second]);
         Quiet : constant Run_Outcome := Run_Rg (["--stats", "-q", "hit", First, Second]);
         Inverted : constant Run_Outcome := Run_Rg (["--stats", "-v", "hit", First, Second]);
         Limited_Result : constant Run_Outcome := Run_Rg (["--stats", "-m1", "hit", First, Second]);
         Multiline : constant Run_Outcome := Run_Rg (["--stats", "-U", "hit\nhit", Multi]);
         Disabled : constant Run_Outcome := Run_Rg (["--stats", "--no-stats", "hit", First]);
         Files : constant Run_Outcome := Run_Rg (["--stats", "--files", First, Second]);
         Normal_Bytes : constant Natural := 2 * First'Length + 18;
         Limited_Bytes : constant Natural := First'Length + 9;
      begin
         AUnit.Assertions.Assert
           (Normal.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Normal.Output), LF & "3 matches" & LF)
            and then Test_Support.Contains (To_String (Normal.Output), "2 matched lines" & LF)
            and then Test_Support.Contains (To_String (Normal.Output), "1 files contained matches" & LF)
            and then Test_Support.Contains (To_String (Normal.Output), "2 files searched" & LF)
            and then Test_Support.Contains
              (To_String (Normal.Output), Natural_Image (Normal_Bytes) & " bytes printed" & LF)
            and then Test_Support.Contains (To_String (Normal.Output), "24 bytes searched" & LF)
            and then Test_Support.Contains (To_String (Normal.Output), " seconds spent searching" & LF)
            and then Test_Support.Contains (To_String (Normal.Output), " seconds total" & LF),
            "--stats reports reference-compatible aggregate fields");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Counted.Output), "3 matches" & LF)
            and then Test_Support.Contains (To_String (Counted.Output), "0 bytes printed" & LF),
            "count output is excluded from printed-byte statistics");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Quiet.Output), "3 matches" & LF)
            and then Test_Support.Contains (To_String (Quiet.Output), "2 files searched" & LF)
            and then not Test_Support.Contains (To_String (Quiet.Output), "hit one"),
            "statistics disable quiet-mode short circuit without printing matches");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Inverted.Output), LF & "0 matches" & LF)
            and then Test_Support.Contains (To_String (Inverted.Output), "2 matched lines" & LF)
            and then Test_Support.Contains (To_String (Inverted.Output), "2 files contained matches" & LF),
            "inverted statistics distinguish matches from selected lines");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Limited_Result.Output), LF & "1 matches" & LF)
            and then Test_Support.Contains (To_String (Limited_Result.Output), "13 bytes searched" & LF)
            and then Test_Support.Contains
              (To_String (Limited_Result.Output), Natural_Image (Limited_Bytes) & " bytes printed" & LF),
            "maximum-count statistics include only searched and rendered records");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Multiline.Output), LF & "1 matches" & LF)
            and then Test_Support.Contains (To_String (Multiline.Output), "2 matched lines" & LF)
            and then Test_Support.Contains (To_String (Multiline.Output), "12 bytes searched" & LF),
            "multiline statistics count touched lines and buffered bytes");
         AUnit.Assertions.Assert
           (not Test_Support.Contains (To_String (Disabled.Output), " matched lines" & LF)
            and then To_String (Files.Output) = First & LF & Second & LF,
            "--no-stats wins and discovery mode remains statistics-free");
      end;

      Test_Support.Delete_If_Exists (First);
      Test_Support.Delete_If_Exists (Second);
      Test_Support.Delete_If_Exists (Multi);
   end Test_Statistics;
end Rg_Stats_Tests;
