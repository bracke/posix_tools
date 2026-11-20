with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Commands.Rg.Patterns;
with Posix_Tools.Commands.Rg.Traversal;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Rg_Robustness_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;
   use type Posix_Tools.Commands.Rg.Patterns.Pattern_Status;

   type Run_Outcome is record
      Output : Unbounded_String;
      Errors : Unbounded_String;
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
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Faults (T : in out Fixture) is
      pragma Unreferenced (T);
      Root       : constant String := Test_Support.Work_Path ("rg-robustness");
      Vanishing  : constant String := Root & "/vanishing.txt";
      Empty_File : constant String := Root & "/empty.txt";
   begin
      Test_Support.Delete_If_Exists (Root);
      Ada.Directories.Create_Path (Root);
      Test_Support.Write_File (Vanishing, "hit" & ASCII.LF);
      Test_Support.Write_File (Empty_File, "");

      declare
         Context : Test_Contexts.Capturing_Context;
         Result  : Posix_Tools.Commands.Results.Result;
      begin
         Context.Initialize ("rg", ["hit"]);
         Test_Contexts.Set_Standard_Input (Context, "hit" & ASCII.LF);
         Test_Contexts.Set_Output_Failure_After (Context, 1);
         Posix_Tools.Commands.Rg.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Commands.Rg.Trouble
            and then Context.Output_Failed,
            "broken stdout cancels safely and reports status 2");
      end;

      declare
         Context : Test_Contexts.Capturing_Context;
         Result  : Posix_Tools.Commands.Results.Result;
      begin
         Context.Initialize ("rg", ["hit"]);
         Test_Contexts.Set_Standard_Input (Context, "hit" & ASCII.LF);
         Test_Contexts.Set_Standard_Input_Failure_After (Context, 1);
         Posix_Tools.Commands.Rg.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains (Test_Contexts.Error_Output (Context), "read failed"),
            "stream failure becomes a diagnostic instead of a crash");
      end;

      declare
         Context    : Test_Contexts.Capturing_Context;
         Files      : Posix_Tools.Commands.Rg.Traversal.File_Set;
         Discovery  : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome;
         Searched   : Posix_Tools.Commands.Rg.Traversal.Traversal_Outcome;
         Options    : Posix_Tools.Commands.Rg.Traversal.Traversal_Options := (others => <>);
         Patterns   : Posix_Tools.Commands.Rg.Patterns.Compiled_Pattern_Array (1 .. 1);
         Diagnostic : Posix_Tools.Commands.Rg.Patterns.Compile_Diagnostic;
      begin
         Context.Initialize ("rg", Posix_Tools.Arguments.Empty);
         Posix_Tools.Commands.Rg.Patterns.Compile
           ("hit", (others => <>), Patterns (1), Diagnostic);
         AUnit.Assertions.Assert
           (Diagnostic.Status = Posix_Tools.Commands.Rg.Patterns.Pattern_Ok,
            "vanishing-file fixture pattern compiles");
         Posix_Tools.Commands.Rg.Traversal.Collect_Tree
           (Context, Root, (others => <>), Files, Discovery);
         AUnit.Assertions.Assert
           (Posix_Tools.Commands.Rg.Traversal.File_Count (Files) = 2,
            "vanishing file is discovered before removal");
         Test_Support.Delete_If_Exists (Vanishing);
         Options.Threads := 4;
         Posix_Tools.Commands.Rg.Traversal.Search_Files
           (Context, Files, Patterns, Options, Searched);
         AUnit.Assertions.Assert
           (Searched.Input_Error
            and then Test_Support.Contains (Test_Contexts.Error_Output (Context), "cannot read"),
            "a file removed after discovery is diagnosed without crashing workers");
      end;

      declare
         Empty : constant Run_Outcome := Run_Rg (["hit", Empty_File], "");
         Chunk : constant String (1 .. 65_536) := [others => 'a'];
         Large : Unbounded_String;
      begin
         AUnit.Assertions.Assert
           (Empty.Status = Posix_Tools.Commands.Rg.No_Matches
            and then To_String (Empty.Output) = ""
            and then To_String (Empty.Errors) = "",
            "an empty file reports no matches without an error");
         for Index in 1 .. 65 loop
            pragma Unreferenced (Index);
            Append (Large, Chunk);
         end loop;
         Append (Large, ASCII.LF);
         declare
            Over_Limit : constant Run_Outcome := Run_Rg (["z"], To_String (Large));
         begin
            AUnit.Assertions.Assert
              (Over_Limit.Status = Posix_Tools.Commands.Rg.Trouble
               and then Test_Support.Contains (To_String (Over_Limit.Errors), "4 MiB search limit"),
               "an over-limit record has an explicit bounded-resource failure");
         end;
      end;

      Test_Support.Delete_If_Exists (Root);
   end Test_Faults;

   procedure Test_Fixed_String_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Random_State is mod 2 ** 32;
      State : Random_State := 16#5EED_1234#;

      function Next_Character return Character is
      begin
         State := State * 1_664_525 + 1_013_904_223;
         return Character'Val (Character'Pos ('a') + Integer (State mod 4));
      end Next_Character;
   begin
      for Case_Number in 1 .. 128 loop
         declare
            Haystack : String (1 .. 32);
            Needle   : String (1 .. 3);
         begin
            for Ch of Haystack loop
               Ch := Next_Character;
            end loop;
            for Ch of Needle loop
               Ch := Next_Character;
            end loop;
            declare
               Expected : constant Boolean := Test_Support.Contains (Haystack, Needle);
               Actual   : constant Run_Outcome := Run_Rg (["-F", Needle], Haystack & ASCII.LF);
            begin
               AUnit.Assertions.Assert
                 ((Actual.Status = Posix_Tools.Exit_Status.Success) = Expected,
                  "fixed-string property status case" & Positive'Image (Case_Number));
               AUnit.Assertions.Assert
                 (To_String (Actual.Output) = (if Expected then Haystack & ASCII.LF else ""),
                  "fixed-string property output case" & Positive'Image (Case_Number));
            end;
         end;
      end loop;
   end Test_Fixed_String_Property;
end Rg_Robustness_Tests;
