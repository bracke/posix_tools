with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Explore.String_Vectors;
with Posix_Tools.File_Operations;

--  File operations run away from the screen.
--
--  A job copies, moves, links, or deletes a list of entries through the
--  shared Posix_Tools.File_Operations. Jobs run on a few workers, in the order
--  they were asked for as far as that is safe: no two jobs of one kind run at
--  once, and no two jobs whose paths overlap -- one the same as, or inside,
--  another -- so a delete never races the copy it would remove. While a job
--  runs, the screen reads its progress from the board, can cancel it, and is
--  asked what to do when a target already exists: the job waits for the
--  answer, so nothing is overwritten that the user did not agree to.
package Explore.Jobs is
   type Job_Kind is (Copy_Job, Move_Job, Link_Job, Delete_Job);

   type Job is record
      Kind    : Job_Kind := Copy_Job;
      --  Absolute paths of the entries to act on.
      Sources : Explore.String_Vectors.Vector;
      --  Where copies, moves, and links go; unused for deletion.
      Target  : Ada.Strings.Unbounded.Unbounded_String;
      --  Given by the board when the job is queued, from 1.
      Id      : Natural := 0;
   end record;

   package Job_Vectors is new Ada.Containers.Vectors (Positive, Job);

   type Conflict_Answer is (Overwrite_One, Skip_One, Overwrite_All, Skip_All);

   --  How many jobs can run at once.
   Lane_Count : constant := 2;

   subtype Lane_Index is Positive range 1 .. Lane_Count;

   --  A job as the screen shows it.
   type Job_View is record
      Id    : Natural := 0;
      Kind  : Job_Kind := Copy_Job;
      --  Its first entry's name, and how many it has.
      First : Ada.Strings.Unbounded.Unbounded_String;
      Total : Natural := 0;
   end record;

   function View_Of (Item : Job) return Job_View;

   package View_Vectors is new Ada.Containers.Vectors (Positive, Job_View);

   type Lane_View is record
      Running    : Boolean := False;
      Job        : Job_View;
      --  Entries done, the file being copied, and how far.
      Done       : Natural := 0;
      Current    : Ada.Strings.Unbounded.Unbounded_String;
      Copied     : Long_Long_Integer := 0;
      Size       : Long_Long_Integer := 0;
      --  Waiting for an answer about a target that exists.
      Asking     : Boolean := False;
      Conflict   : Ada.Strings.Unbounded.Unbounded_String;
      Cancelling : Boolean := False;
   end record;

   type Lane_Views is array (Lane_Index) of Lane_View;

   type Outcome is (Succeeded, Failed, Cancelled);

   --  A job that has ended.
   type Result_View is record
      Job        : Job_View;
      Done       : Natural := 0;
      Ended      : Outcome := Succeeded;
      Errors     : Natural := 0;
      Error_Path : Ada.Strings.Unbounded.Unbounded_String;
      Error      : Posix_Tools.File_Operations.Operation_Error := Posix_Tools.File_Operations.Cannot_Open;
   end record;

   package Result_Vectors is new Ada.Containers.Vectors (Positive, Result_View);

   --  What the screen shows of the jobs.
   type Snapshot is record
      Lanes     : Lane_Views;
      Queued    : View_Vectors.Vector;
      --  The latest ended jobs, the newest last.
      History   : Result_Vectors.Vector;
      --  Bumped when a job ends, for the screen to re-read what it changed.
      Completed : Natural := 0;
   end record;

   function Any_Running (Item : Snapshot) return Boolean is (for some Lane of Item.Lanes => Lane.Running);

   --  The lane whose job waits for an answer; zero when none does.
   function Asking_Lane (Item : Snapshot) return Natural;

   --  Counts the changes to what Status shows, so that the screen can tell
   --  that nothing changed without taking a snapshot. It goes round.
   type Version_Number is mod 2 ** 32;

   Max_Queued  : constant := 16;
   Max_History : constant := 16;

   --  What the board keeps for each lane, for its own use.
   type Job_Array is private;
   type Flag_Array is private;
   type Answer_Array is private;
   type Result_Array is private;

   protected type Board is
      --  Queue a job. Accepted is False when the queue is full.
      procedure Submit (Item : Job; Accepted : out Boolean);

      --  Cancel the job with Id: a running one stops at its next entry or
      --  block, a queued one is dropped before it starts.
      procedure Cancel (Id : Natural);

      --  Cancel every running job.
      procedure Cancel_Running;

      --  Answer the question of the lane Asking_Lane names.
      procedure Answer (Choice : Conflict_Answer);

      function Status return Snapshot;

      --  Changed whenever Status would show something else; the same may
      --  still show the same, as when progress is reported twice alike.
      function Version return Version_Number;

      procedure Shut_Down;

      --  For the workers.
      entry Take (Item : out Job; Lane : out Lane_Index; Closed : out Boolean);
      procedure Begin_Item (Lane : Lane_Index; Path : String);
      procedure Report_Progress (Lane : Lane_Index; Copied, Size : Long_Long_Integer);
      procedure End_Item (Lane : Lane_Index);
      procedure Report_Error
        (Lane  : Lane_Index;
         Path  : String;
         Error : Posix_Tools.File_Operations.Operation_Error);
      procedure Ask (Lane : Lane_Index; Target : String);
      entry Wait_Answer (Lane_Index) (Choice : out Conflict_Answer);
      function Cancel_Requested (Lane : Lane_Index) return Boolean;
      procedure Finish (Lane : Lane_Index);
   private
      --  Count the queued jobs that may start now, for Take's barrier.
      procedure Recount;

      --  Note that what Status shows changed.
      procedure Changed;

      Queue     : Job_Vectors.Vector;
      Lanes     : Lane_Views;
      Running   : Job_Array;
      Answered  : Flag_Array;
      Replies   : Answer_Array;
      Results   : Result_Array;
      History   : Result_Vectors.Vector;
      Startable : Natural := 0;
      Last_Id   : Natural := 0;
      Completed : Natural := 0;
      Closed    : Boolean := False;
      Changes   : Version_Number := 0;
   end Board;

   task type Worker (Jobs : not null access Board);

   --  Where Source goes in Directory: its own name there, or, when that is
   --  Source itself, the first of "name_1", "name_2", ... that is free.
   function Destination (Source, Directory : String) return String;

   --  Whether Left and Right touch the same paths: a path of one that is a
   --  path of the other, or lies inside one.
   function Overlap (Left, Right : Job) return Boolean;

private
   type Job_Array is array (Lane_Index) of Job;
   type Flag_Array is array (Lane_Index) of Boolean with Default_Component_Value => False;
   type Answer_Array is array (Lane_Index) of Conflict_Answer with Default_Component_Value => Skip_One;
   type Result_Array is array (Lane_Index) of Result_View;
end Explore.Jobs;
