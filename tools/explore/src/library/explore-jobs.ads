with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Explore.Model;
with Posix_Tools.File_Operations;

--  File operations run away from the screen, one job at a time, in the order
--  they were asked for.
--
--  A job copies, moves, links, or deletes a list of entries through the
--  shared Posix_Tools.File_Operations. While it runs, the screen reads its
--  progress from the board, can cancel it, and is asked what to do when a
--  target already exists: the worker waits for the answer, so nothing is
--  overwritten that the user did not agree to.
package Explore.Jobs is
   package Path_Vectors renames Explore.Model.Path_Vectors;

   type Job_Kind is (Copy_Job, Move_Job, Link_Job, Delete_Job);

   type Job is record
      Kind    : Job_Kind := Copy_Job;
      --  Absolute paths of the entries to act on.
      Sources : Path_Vectors.Vector;
      --  Where copies, moves, and links go; unused for deletion.
      Target  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Job_Vectors is new Ada.Containers.Vectors (Positive, Job);

   type Conflict_Answer is (Overwrite_One, Skip_One, Overwrite_All, Skip_All);

   --  What the screen shows of the jobs.
   type Snapshot is record
      Running     : Boolean := False;
      Kind        : Job_Kind := Copy_Job;
      --  Entries of the running job done, and how many it has.
      Done        : Natural := 0;
      Total       : Natural := 0;
      --  The file being copied, and how far.
      Current     : Ada.Strings.Unbounded.Unbounded_String;
      Copied      : Long_Long_Integer := 0;
      Size        : Long_Long_Integer := 0;
      Queued      : Natural := 0;
      --  Waiting for an answer about a target that exists.
      Asking      : Boolean := False;
      Conflict    : Ada.Strings.Unbounded.Unbounded_String;
      --  Errors since the screen last cleared them, and the latest.
      Errors      : Natural := 0;
      Error_Path  : Ada.Strings.Unbounded.Unbounded_String;
      Error       : Posix_Tools.File_Operations.Operation_Error := Posix_Tools.File_Operations.Cannot_Open;
      --  Bumped when a job ends, for the screen to re-read what it changed.
      Completed   : Natural := 0;
   end record;

   Max_Queued : constant := 16;

   protected type Board is
      --  Queue a job. Accepted is False when the queue is full.
      procedure Submit (Item : Job; Accepted : out Boolean);

      --  Stop the running job at its next entry or block, and drop it.
      procedure Cancel;

      --  The answer to the question Snapshot.Asking shows.
      procedure Answer (Choice : Conflict_Answer);

      procedure Clear_Errors;

      function Status return Snapshot;

      procedure Shut_Down;

      --  For the worker.
      entry Take (Item : out Job; Closed : out Boolean);
      procedure Start (Kind : Job_Kind; Total : Natural);
      procedure Begin_Item (Path : String);
      procedure Report_Progress (Copied, Size : Long_Long_Integer);
      procedure End_Item;
      procedure Report_Error (Path : String; Error : Posix_Tools.File_Operations.Operation_Error);
      procedure Ask (Target : String);
      entry Wait_Answer (Choice : out Conflict_Answer);
      function Cancel_Requested return Boolean;
      procedure Finish;
   private
      Queue      : Job_Vectors.Vector;
      State      : Snapshot;
      Cancelling : Boolean := False;
      Answered   : Boolean := False;
      Reply      : Conflict_Answer := Skip_One;
      Closed     : Boolean := False;
   end Board;

   task type Worker (Jobs : not null access Board);

   --  Where Source goes in Directory: its own name there, or, when that is
   --  Source itself, the first of "name_1", "name_2", ... that is free.
   function Destination (Source, Directory : String) return String;
end Explore.Jobs;
