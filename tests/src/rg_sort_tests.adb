with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Test_Contexts;
with Test_Support;

package body Rg_Sort_Tests is
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

   procedure Test_Path_Sorting (T : in out Fixture) is
      pragma Unreferenced (T);
      LF      : constant Character := ASCII.LF;
      Root    : constant String := Test_Support.Work_Path ("rg-sort");
      A_Dir   : constant String := Root & "/a";
      A_Sub   : constant String := A_Dir & "/sub";
      B_Dir   : constant String := Root & "/b";
      A_First : constant String := A_Dir & "/a.txt";
      A_Deep  : constant String := A_Sub & "/c.txt";
      A_Last  : constant String := A_Dir & "/z.txt";
      B_First : constant String := B_Dir & "/b.txt";
      B_Last  : constant String := B_Dir & "/m.txt";
   begin
      Ada.Directories.Create_Path (A_Sub);
      Ada.Directories.Create_Path (B_Dir);
      Test_Support.Write_File (A_First, "hit a" & LF);
      Test_Support.Write_File (A_Deep, "hit c" & LF);
      Test_Support.Write_File (A_Last, "hit z" & LF);
      Test_Support.Write_File (B_First, "hit b" & LF);
      Test_Support.Write_File (B_Last, "hit m" & LF);

      declare
         package FS renames Posix_Tools.Host_Adapters.File_System;
         Time_2018 : FS.File_Time;
         Time_2019 : FS.File_Time;
         Time_2020 : FS.File_Time;
         Time_2021 : FS.File_Time;
         Time_2022 : FS.File_Time;
      begin
         AUnit.Assertions.Assert
           (FS.File_Time_Of (2018, 1, 1, 1, 1, 0, Time_2018)
            and then FS.File_Time_Of (2019, 1, 1, 1, 1, 0, Time_2019)
            and then FS.File_Time_Of (2020, 1, 1, 1, 1, 0, Time_2020)
            and then FS.File_Time_Of (2021, 1, 1, 1, 1, 0, Time_2021)
            and then FS.File_Time_Of (2022, 1, 1, 1, 1, 0, Time_2022),
            "metadata sort fixture timestamps are representable");
         AUnit.Assertions.Assert
           (FS.Set_File_Times (A_Deep, Time_2018, Time_2018)
            and then FS.Set_File_Times (A_Last, Time_2019, Time_2019)
            and then FS.Set_File_Times (B_First, Time_2020, Time_2020)
            and then FS.Set_File_Times (A_First, Time_2021, Time_2021)
            and then FS.Set_File_Times (B_Last, Time_2022, Time_2022),
            "metadata sort fixture timestamps are installed");
      end;

      declare
         Files_Ascending : constant Run_Outcome :=
           Run_Rg (["--files", "--sort", "path", Root]);
         Files_Descending : constant Run_Outcome :=
           Run_Rg (["--files", "--sortr=path", Root]);
         Accessed : constant Run_Outcome :=
           Run_Rg (["--sort", "accessed", "hit", B_Dir, A_Dir]);
         Search_Ascending : constant Run_Outcome :=
           Run_Rg (["--sort=path", "hit", Root]);
         Roots_Descending : constant Run_Outcome :=
           Run_Rg (["--sortr", "path", "hit", B_Dir, A_Dir]);
         Explicit_Files : constant Run_Outcome :=
           Run_Rg (["--files", "--sort", "path", B_Last, A_Last, A_First]);
         Last_Wins : constant Run_Outcome :=
           Run_Rg (["--files", "--sortr", "path", "--sort", "path", Root]);
         No_Sort : constant Run_Outcome :=
           Run_Rg (["--files", "--sort", "none", Root]);
         Modified : constant Run_Outcome :=
           Run_Rg (["--files", "--sort", "modified", B_Dir, A_Dir]);
         Modified_Reverse : constant Run_Outcome :=
           Run_Rg (["--files", "--sortr", "modified", B_Dir, A_Dir]);
         Explicit_Metadata : constant Run_Outcome :=
           Run_Rg (["--files", "--sort", "modified", B_Last, A_First, A_Last]);
         Created : constant Run_Outcome :=
           Run_Rg (["--files", "--sort", "created", A_First]);
         Stdin_Ascending : constant Run_Outcome :=
           Run_Rg (["--files", "--sort", "modified", "-", A_First]);
         Stdin_Descending : constant Run_Outcome :=
           Run_Rg (["--files", "--sortr", "modified", "-", A_First]);
         Invalid : constant Run_Outcome :=
           Run_Rg (["--sort=banana", "hit", Root]);
         Ascending : constant String :=
           A_First & LF & A_Deep & LF & A_Last & LF & B_First & LF & B_Last & LF;
      begin
         AUnit.Assertions.Assert
           (Files_Ascending.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Files_Ascending.Output) = Ascending,
            "--files sorts discovered paths ascending");
         AUnit.Assertions.Assert
           (To_String (Files_Descending.Output) =
              B_Last & LF & B_First & LF & A_Last & LF & A_Deep & LF & A_First & LF,
            "--sortr sorts discovered paths descending");
         AUnit.Assertions.Assert
           (To_String (Search_Ascending.Output) =
              A_First & ":hit a" & LF
              & A_Deep & ":hit c" & LF
              & A_Last & ":hit z" & LF
              & B_First & ":hit b" & LF
              & B_Last & ":hit m" & LF,
            "search output follows sorted path order");
         AUnit.Assertions.Assert
           (To_String (Roots_Descending.Output) =
              B_Last & ":hit m" & LF
              & B_First & ":hit b" & LF
              & A_Last & ":hit z" & LF
              & A_Deep & ":hit c" & LF
              & A_First & ":hit a" & LF,
            "sorting is local to each directory operand");
         AUnit.Assertions.Assert
           (To_String (Explicit_Files.Output) = B_Last & LF & A_Last & LF & A_First & LF,
            "sorting preserves explicit file operand order");
         AUnit.Assertions.Assert
           (To_String (Last_Wins.Output) = Ascending,
            "the last sorting option wins");
         AUnit.Assertions.Assert
           (No_Sort.Status = Posix_Tools.Exit_Status.Success,
            "--sort none restores ordinary traversal");
         AUnit.Assertions.Assert
           (To_String (Modified.Output) =
              A_Deep & LF & A_Last & LF & B_First & LF & A_First & LF & B_Last & LF
            and then To_String (Modified_Reverse.Output) =
              B_Last & LF & A_First & LF & B_First & LF & A_Last & LF & A_Deep & LF,
            "modification sorting is global across directory operands");
         AUnit.Assertions.Assert
           (To_String (Accessed.Output) =
              A_Deep & ":hit c" & LF
              & A_Last & ":hit z" & LF
              & B_First & ":hit b" & LF
              & A_First & ":hit a" & LF
              & B_Last & ":hit m" & LF,
            "access-time sorting controls search output globally");
         AUnit.Assertions.Assert
           (To_String (Explicit_Metadata.Output) = A_Last & LF & A_First & LF & B_Last & LF,
            "metadata sorting reorders explicit file operands");
         AUnit.Assertions.Assert
           (Created.Status = Posix_Tools.Exit_Status.Success
            or else
              (Created.Status = Posix_Tools.Commands.Rg.Trouble
               and then Test_Support.Contains
                 (To_String (Created.Errors), "cannot read creation time")),
            "creation sorting succeeds when the filesystem exposes birth time or fails explicitly");
         AUnit.Assertions.Assert
           (To_String (Stdin_Ascending.Output) = A_First & LF & "<stdin>" & LF
            and then To_String (Stdin_Descending.Output) = "<stdin>" & LF & A_First & LF,
            "standard input sorts after metadata ascending and before it descending");
         AUnit.Assertions.Assert
           (Invalid.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains
              (To_String (Invalid.Errors), "invalid value for --sort: banana"),
            "invalid sort keys have a deterministic diagnostic");
      end;

      Test_Support.Delete_If_Exists (Root);
   end Test_Path_Sorting;
end Rg_Sort_Tests;
