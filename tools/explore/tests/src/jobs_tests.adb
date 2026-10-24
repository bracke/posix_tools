with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Explore.Jobs;
with Posix_Tools.Host_Adapters.File_System;

package body Jobs_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Jobs renames Explore.Jobs;
   package Unbounded renames Ada.Strings.Unbounded;

   function Root return String is (Ada.Directories.Current_Directory & "/obj/jobs-fixture");

   function Path (Name : String) return String is (Root & "/" & Name);

   --  Root with a file, a directory holding a file, and an empty "into".
   procedure Make_Fixture;

   function Sources (A : String; B : String := "") return Jobs.Path_Vectors.Vector;

   --  Wait until the board has finished Count jobs, answering every
   --  question with Answer.
   procedure Wait_For
     (Board  : in out Jobs.Board;
      Count  : Natural;
      Answer : Jobs.Conflict_Answer := Jobs.Skip_One);

   procedure Write (Name, Text : String);

   procedure Make_Fixture is
   begin
      if FS.Exists (Root) then
         Ada.Directories.Delete_Tree (Root);
      end if;

      Ada.Directories.Create_Path (Path ("dir"));
      Ada.Directories.Create_Path (Path ("into"));
      Write (Path ("file"), "file");
      Write (Path ("dir/inner"), "inner");
   end Make_Fixture;

   function Sources (A : String; B : String := "") return Jobs.Path_Vectors.Vector is
      Result : Jobs.Path_Vectors.Vector;
   begin
      Result.Append (A);

      if B /= "" then
         Result.Append (B);
      end if;

      return Result;
   end Sources;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("jobs:destination", Test_Destination'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("jobs:copy and delete", Test_Copy_And_Delete'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("jobs:conflict question", Test_Conflict_Question'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("jobs:cancel", Test_Cancel'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("jobs:queue bound", Test_Queue_Bound'Access));
      return Result;
   end Suite;

   procedure Test_Cancel (T : in out Fixture) is
      pragma Unreferenced (T);
      Board    : aliased Jobs.Board;
      Worker   : Jobs.Worker (Board'Access);
      Accepted : Boolean;
   begin
      Make_Fixture;
      Write (Path ("into/file"), "existing");
      Board.Submit
        ((Jobs.Copy_Job, Sources (Path ("file"), Path ("dir")), Unbounded.To_Unbounded_String (Path ("into"))),
         Accepted);

      --  The job stops at its question; cancelling it answers for the user.
      for Attempt in 1 .. 500 loop
         exit when Board.Status.Asking;
         delay 0.01;
      end loop;

      AUnit.Assertions.Assert (Board.Status.Asking, "the job asks about the existing file");
      Board.Cancel;
      Wait_For (Board, 1);
      AUnit.Assertions.Assert
        (not FS.Exists (Path ("into/dir")) and then FS.Size (Path ("into/file")) = 8,
         "a cancelled job overwrites nothing and goes no further");
      Board.Shut_Down;
   end Test_Cancel;

   procedure Test_Conflict_Question (T : in out Fixture) is
      pragma Unreferenced (T);
      Board    : aliased Jobs.Board;
      Worker   : Jobs.Worker (Board'Access);
      Accepted : Boolean;
   begin
      Make_Fixture;
      Write (Path ("into/file"), "existing");

      Board.Submit ((Jobs.Copy_Job, Sources (Path ("file")), Unbounded.To_Unbounded_String (Path ("into"))), Accepted);
      Wait_For (Board, 1, Jobs.Skip_One);
      AUnit.Assertions.Assert (FS.Size (Path ("into/file")) = 8, "skipped: the existing file stays");

      Board.Submit ((Jobs.Copy_Job, Sources (Path ("file")), Unbounded.To_Unbounded_String (Path ("into"))), Accepted);
      Wait_For (Board, 2, Jobs.Overwrite_One);
      AUnit.Assertions.Assert (FS.Size (Path ("into/file")) = 4, "overwritten");

      Board.Submit ((Jobs.Move_Job, Sources (Path ("file")), Unbounded.To_Unbounded_String (Path ("into"))), Accepted);
      Wait_For (Board, 3, Jobs.Overwrite_All);
      AUnit.Assertions.Assert
        (not FS.Exists (Path ("file")) and then FS.Exists (Path ("into/file")), "moved over it");
      Board.Shut_Down;
   end Test_Conflict_Question;

   procedure Test_Copy_And_Delete (T : in out Fixture) is
      pragma Unreferenced (T);
      Board    : aliased Jobs.Board;
      Worker   : Jobs.Worker (Board'Access);
      Accepted : Boolean;
   begin
      Make_Fixture;
      Board.Submit
        ((Jobs.Copy_Job, Sources (Path ("file"), Path ("dir")), Unbounded.To_Unbounded_String (Path ("into"))),
         Accepted);
      AUnit.Assertions.Assert (Accepted, "queued");
      Wait_For (Board, 1);
      AUnit.Assertions.Assert
        (FS.Exists (Path ("into/file")) and then FS.Exists (Path ("into/dir/inner")), "both copied, the tree whole");
      AUnit.Assertions.Assert
        (Board.Status.Done = 2 and then Board.Status.Total = 2 and then Board.Status.Errors = 0, "counted");

      Board.Submit ((Jobs.Copy_Job, Sources (Path ("file")), Unbounded.To_Unbounded_String (Root)), Accepted);
      Wait_For (Board, 2);
      AUnit.Assertions.Assert (FS.Exists (Path ("file_1")), "a copy into its own directory gets a new name");

      Board.Submit ((Jobs.Delete_Job, Sources (Path ("into/file"), Path ("into/dir")), others => <>), Accepted);
      Board.Submit ((Jobs.Link_Job, Sources (Path ("dir")), Unbounded.To_Unbounded_String (Path ("into"))), Accepted);
      Wait_For (Board, 4);
      AUnit.Assertions.Assert
        (not FS.Exists (Path ("into/file")) and then FS.Is_Link (Path ("into/dir")),
         "jobs run in order: the copies went, and a link took the directory's place");
      Board.Submit ((Jobs.Delete_Job, Sources (Path ("into/dir")), others => <>), Accepted);
      Wait_For (Board, 5);
      AUnit.Assertions.Assert
        (not FS.Is_Link (Path ("into/dir")) and then FS.Exists (Path ("dir/inner")),
         "deleting the link leaves what it points to");
      Board.Shut_Down;
   end Test_Copy_And_Delete;

   procedure Test_Destination (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      Make_Fixture;
      AUnit.Assertions.Assert (Jobs.Destination (Path ("file"), Path ("into")) = Path ("into/file"), "its own name");
      AUnit.Assertions.Assert (Jobs.Destination (Path ("file"), Root) = Path ("file_1"), "a free name beside itself");
      Write (Path ("file_1"), "");
      AUnit.Assertions.Assert (Jobs.Destination (Path ("file"), Root & "/") = Path ("file_2"), "the next free one");
   end Test_Destination;

   procedure Test_Queue_Bound (T : in out Fixture) is
      pragma Unreferenced (T);
      Board    : Jobs.Board;
      Accepted : Boolean;
   begin
      --  No worker: nothing is taken off the queue.
      for I in 1 .. Jobs.Max_Queued loop
         Board.Submit ((Jobs.Delete_Job, Sources ("/nonexistent"), others => <>), Accepted);
         AUnit.Assertions.Assert (Accepted, "queued while there is room");
      end loop;

      Board.Submit ((Jobs.Delete_Job, Sources ("/nonexistent"), others => <>), Accepted);
      AUnit.Assertions.Assert (not Accepted and then Board.Status.Queued = Jobs.Max_Queued, "a full queue refuses");
      Board.Shut_Down;
   end Test_Queue_Bound;

   procedure Wait_For
     (Board  : in out Jobs.Board;
      Count  : Natural;
      Answer : Jobs.Conflict_Answer := Jobs.Skip_One)
   is
   begin
      for Attempt in 1 .. 1000 loop
         exit when Board.Status.Completed >= Count;

         if Board.Status.Asking then
            Board.Answer (Answer);
         end if;

         delay 0.01;
      end loop;

      AUnit.Assertions.Assert (Board.Status.Completed >= Count, "job finished in time");
   end Wait_For;

   procedure Write (Name, Text : String) is
      Ok : Boolean;
   begin
      FS.Write_File (Name, Text, Append_Mode => False, Ok => Ok);
      AUnit.Assertions.Assert (Ok, "fixture written: " & Name);
   end Write;
end Jobs_Tests;
