with Explore.Model;
with Posix_Tools.File_Operations.Copying;
with Posix_Tools.File_Operations.Moving;
with Posix_Tools.File_Operations.Removing;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Numeric_Images;

package body Explore.Jobs is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Model renames Explore.Model;
   package Ops renames Posix_Tools.File_Operations;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Ops.Conflict_Choice;

   --  How a job's operations reach the board.
   type Job_Observer (Jobs : not null access Board; Lane : Lane_Index) is new Ops.Observer with record
      --  The answer given for every conflict, once the user chose one.
      Settled : Boolean := False;
      Always  : Ops.Conflict_Choice := Ops.Skip;
      --  The file whose progress is being reported, and its size.
      Copying : Unbounded.Unbounded_String;
      Size    : Long_Long_Integer := 0;
   end record;

   overriding procedure Report_Error (Self : in out Job_Observer; Path : String; Error : Ops.Operation_Error);
   overriding function Cancelled (Self : in out Job_Observer) return Boolean;
   overriding procedure Progress (Self : in out Job_Observer; Path : String; Copied : Long_Long_Integer);
   overriding function Resolve_Conflict
     (Self : in out Job_Observer; Source, Target : String) return Ops.Conflict_Choice;

   --  Run one entry of a job.
   procedure Run_Item (Item : Job; Source : String; Watcher : in out Job_Observer'Class);

   --  The first queued job that may start now: a lane is free, no job of
   --  its kind runs, and it overlaps neither a running job nor one queued
   --  before it. Zero when none may.
   function Startable_Index (Queue : Job_Vectors.Vector; Lanes : Lane_Views; Running : Job_Array) return Natural;

   function Asking_Lane (Item : Snapshot) return Natural is
   begin
      for Lane in Item.Lanes'Range loop
         if Item.Lanes (Lane).Asking then
            return Lane;
         end if;
      end loop;

      return 0;
   end Asking_Lane;

   protected body Board is
      procedure Answer (Choice : Conflict_Answer) is
      begin
         for Lane in Lanes'Range loop
            if Lanes (Lane).Asking then
               Replies (Lane) := Choice;
               Answered (Lane) := True;
               Lanes (Lane).Asking := False;
               Lanes (Lane).Conflict := Unbounded.Null_Unbounded_String;
               Changed;
               return;
            end if;
         end loop;
      end Answer;

      procedure Ask (Lane : Lane_Index; Target : String) is
      begin
         Answered (Lane) := False;
         Lanes (Lane).Asking := True;
         Lanes (Lane).Conflict := Unbounded.To_Unbounded_String (Target);
         Changed;
      end Ask;

      procedure Begin_Item (Lane : Lane_Index; Path : String) is
      begin
         Lanes (Lane).Current := Unbounded.To_Unbounded_String (Path);
         Lanes (Lane).Copied := 0;
         Lanes (Lane).Size := 0;
         Changed;
      end Begin_Item;

      procedure Cancel (Id : Natural) is
      begin
         for Lane in Lanes'Range loop
            if Lanes (Lane).Running and then Lanes (Lane).Job.Id = Id then
               Lanes (Lane).Cancelling := True;
               Changed;
               return;
            end if;
         end loop;

         for I in 1 .. Natural (Queue.Length) loop
            if Queue (I).Id = Id then
               History.Append (Result_View'(Job => View_Of (Queue (I)), Ended => Cancelled, others => <>));

               if Natural (History.Length) > Max_History then
                  History.Delete_First;
               end if;

               Queue.Delete (I);
               Completed := Completed + 1;
               Recount;
               Changed;
               return;
            end if;
         end loop;
      end Cancel;

      function Cancel_Requested (Lane : Lane_Index) return Boolean is (Lanes (Lane).Cancelling or else Closed);

      procedure Cancel_Running is
      begin
         for Lane in Lanes'Range loop
            if Lanes (Lane).Running then
               Lanes (Lane).Cancelling := True;
               Changed;
            end if;
         end loop;
      end Cancel_Running;

      procedure Changed is
      begin
         Changes := Changes + 1;
      end Changed;

      procedure End_Item (Lane : Lane_Index) is
      begin
         Lanes (Lane).Done := Lanes (Lane).Done + 1;
         Changed;
      end End_Item;

      procedure Finish (Lane : Lane_Index) is
         Result : Result_View := Results (Lane);
      begin
         Result.Done := Lanes (Lane).Done;
         Result.Ended :=
           (if Lanes (Lane).Cancelling then Cancelled elsif Result.Errors > 0 then Failed else Succeeded);
         History.Append (Result);

         if Natural (History.Length) > Max_History then
            History.Delete_First;
         end if;

         Lanes (Lane) := (others => <>);
         Running (Lane) := (others => <>);
         Results (Lane) := (others => <>);
         Answered (Lane) := False;
         Completed := Completed + 1;
         Recount;
         Changed;
      end Finish;

      procedure Recount is
      begin
         Startable := (if Startable_Index (Queue, Lanes, Running) > 0 then 1 else 0);
      end Recount;

      procedure Report_Error
        (Lane  : Lane_Index;
         Path  : String;
         Error : Ops.Operation_Error)
      is
      begin
         Results (Lane).Errors := Results (Lane).Errors + 1;

         --  The first error is the one worth showing; later ones often follow from it.
         if Results (Lane).Errors = 1 then
            Results (Lane).Error_Path := Unbounded.To_Unbounded_String (Path);
            Results (Lane).Error := Error;
         end if;
      end Report_Error;

      procedure Report_Progress (Lane : Lane_Index; Copied, Size : Long_Long_Integer) is
      begin
         Lanes (Lane).Copied := Copied;
         Lanes (Lane).Size := Size;
         Changed;
      end Report_Progress;

      procedure Shut_Down is
      begin
         Closed := True;
      end Shut_Down;

      function Status return Snapshot is
         Result : Snapshot := (Lanes => Lanes, History => History, Completed => Completed, others => <>);
      begin
         for Item of Queue loop
            Result.Queued.Append (View_Of (Item));
         end loop;

         return Result;
      end Status;

      procedure Submit (Item : Job; Accepted : out Boolean) is
      begin
         Accepted := not Closed and then Natural (Queue.Length) < Max_Queued and then not Item.Sources.Is_Empty;

         if Accepted then
            Last_Id := Last_Id + 1;
            Queue.Append ((Item with delta Id => Last_Id));
            Recount;
            Changed;
         end if;
      end Submit;

      entry Take (Item : out Job; Lane : out Lane_Index; Closed : out Boolean)
        when Board.Closed or else Startable > 0
      is
         Index : constant Natural := Startable_Index (Queue, Lanes, Running);
      begin
         Closed := Board.Closed;
         Item := (others => <>);
         Lane := Lane_Index'First;

         if Closed or else Index = 0 then
            Closed := True;
            return;
         end if;

         for Free in Lanes'Range loop
            if not Lanes (Free).Running then
               Lane := Free;
               exit;
            end if;
         end loop;

         Item := Queue (Index);
         Queue.Delete (Index);
         Running (Lane) := Item;
         Lanes (Lane) := (Running => True, Job => View_Of (Item), others => <>);
         Results (Lane) := (Job => View_Of (Item), others => <>);
         Recount;
         Changed;
      end Take;

      function Version return Version_Number is (Changes);

      entry Wait_Answer (for Lane in Lane_Index) (Choice : out Conflict_Answer)
        when Answered (Lane) or else Lanes (Lane).Cancelling or else Closed
      is
      begin
         --  A job cancelled while it asked leaves the target alone.
         Choice := (if Answered (Lane) then Replies (Lane) else Skip_One);
         Answered (Lane) := False;
         Lanes (Lane).Asking := False;
         Lanes (Lane).Conflict := Unbounded.Null_Unbounded_String;
         Changed;
      end Wait_Answer;
   end Board;

   overriding function Cancelled (Self : in out Job_Observer) return Boolean is
     (Self.Jobs.Cancel_Requested (Self.Lane));

   function Destination (Source, Directory : String) return String is
      Wanted : constant String := Model.Child_Of (Directory, Model.Name_Of (Source));
   begin
      if Wanted /= Source then
         return Wanted;
      end if;

      for N in 1 .. 10_000 loop
         declare
            Candidate : constant String := Wanted & "_" & Posix_Tools.Text.Numeric_Images.Natural_Image (N);
         begin
            if not FS.Exists (Candidate) and then not FS.Is_Link (Candidate) then
               return Candidate;
            end if;
         end;
      end loop;

      return Wanted;
   end Destination;

   function Overlap (Left, Right : Job) return Boolean is
      --  Whether Inner is Outer or lies inside it.
      function Within (Inner, Outer : String) return Boolean is
        (Inner = Outer
         or else (Inner'Length > Outer'Length
                  and then Inner (Inner'First .. Inner'First + Outer'Length - 1) = Outer
                  and then (Outer (Outer'Last) = '/' or else Inner (Inner'First + Outer'Length) = '/')));

      function Paths (Item : Job) return Explore.String_Vectors.Vector is
        (if Item.Kind = Delete_Job or else Unbounded.Length (Item.Target) = 0 then Item.Sources
         else Explore.String_Vectors."&" (Item.Sources, Unbounded.To_String (Item.Target)));
   begin
      for A of Paths (Left) loop
         for B of Paths (Right) loop
            if Within (A, B) or else Within (B, A) then
               return True;
            end if;
         end loop;
      end loop;

      return False;
   end Overlap;

   overriding procedure Progress (Self : in out Job_Observer; Path : String; Copied : Long_Long_Integer) is
   begin
      if Unbounded.To_String (Self.Copying) /= Path then
         Self.Copying := Unbounded.To_Unbounded_String (Path);
         Self.Size := FS.Size (Path);
         Self.Jobs.Begin_Item (Self.Lane, Path);
      end if;

      Self.Jobs.Report_Progress (Self.Lane, Copied, Self.Size);
   end Progress;

   overriding procedure Report_Error (Self : in out Job_Observer; Path : String; Error : Ops.Operation_Error) is
   begin
      Self.Jobs.Report_Error (Self.Lane, Path, Error);
   end Report_Error;

   overriding function Resolve_Conflict
     (Self : in out Job_Observer; Source, Target : String) return Ops.Conflict_Choice
   is
      pragma Unreferenced (Source);
      Choice : Conflict_Answer;
   begin
      if Self.Settled then
         return Self.Always;
      end if;

      Self.Jobs.Ask (Self.Lane, Target);
      Self.Jobs.Wait_Answer (Self.Lane) (Choice);

      case Choice is
         when Overwrite_One =>
            return Ops.Overwrite;
         when Skip_One =>
            return Ops.Skip;
         when Overwrite_All | Skip_All =>
            Self.Settled := True;
            Self.Always := (if Choice = Overwrite_All then Ops.Overwrite else Ops.Skip);
            return Self.Always;
      end case;
   end Resolve_Conflict;

   procedure Run_Item (Item : Job; Source : String; Watcher : in out Job_Observer'Class) is
      Directory : constant String := Unbounded.To_String (Item.Target);
      Outcome   : Ops.Operation_Outcome;
   begin
      Watcher.Jobs.Begin_Item (Watcher.Lane, Source);

      case Item.Kind is
         when Copy_Job =>
            Ops.Copying.Copy_Path
              (Source,
               Destination (Source, Directory),
               (Recursive => True, Preserve_Mode => True, Preserve_Links => True),
               Watcher,
               Outcome);
         when Move_Job =>
            --  Moving into the directory it is already in moves nothing.
            if Model.Child_Of (Directory, Model.Name_Of (Source)) /= Source then
               Ops.Moving.Move_Path (Source, Model.Child_Of (Directory, Model.Name_Of (Source)), Watcher, Outcome);
            end if;
         when Link_Job =>
            declare
               Target : constant String := Destination (Source, Directory);
            begin
               if (FS.Exists (Target) or else FS.Is_Link (Target))
                 and then Watcher.Resolve_Conflict (Source, Target) = Ops.Skip
               then
                  null;
               elsif (FS.Is_Link (Target) and then not FS.Delete_Link (Target))
                 or else not FS.Create_Link (Source, Target)
               then
                  Watcher.Report_Error (Target, Ops.Cannot_Open);
               end if;
            end;
         when Delete_Job =>
            Ops.Removing.Remove_Path (Source, (Recursive => True, Empty_Directories => False), Watcher, Outcome);
      end case;

      Watcher.Jobs.End_Item (Watcher.Lane);
   end Run_Item;

   function Startable_Index (Queue : Job_Vectors.Vector; Lanes : Lane_Views; Running : Job_Array) return Natural is
   begin
      if (for all Lane of Lanes => Lane.Running) then
         return 0;
      end if;

      for I in 1 .. Natural (Queue.Length) loop
         declare
            Candidate : constant Job := Queue (I);
            Clear     : Boolean := True;
         begin
            for Lane in Lanes'Range loop
               if Lanes (Lane).Running
                 and then (Running (Lane).Kind = Candidate.Kind or else Overlap (Running (Lane), Candidate))
               then
                  Clear := False;
               end if;
            end loop;

            --  An earlier job it overlaps goes first, as asked.
            for J in 1 .. I - 1 loop
               if Overlap (Queue (J), Candidate) then
                  Clear := False;
               end if;
            end loop;

            if Clear then
               return I;
            end if;
         end;
      end loop;

      return 0;
   end Startable_Index;

   function View_Of (Item : Job) return Job_View is
     ((Id    => Item.Id,
       Kind  => Item.Kind,
       First => Unbounded.To_Unbounded_String (if Item.Sources.Is_Empty then "" else Model.Name_Of (Item.Sources (1))),
       Total => Natural (Item.Sources.Length)));

   task body Worker is
      Item   : Job;
      Lane   : Lane_Index;
      Closed : Boolean;
   begin
      loop
         Jobs.Take (Item, Lane, Closed);
         exit when Closed;

         declare
            Watcher : Job_Observer (Jobs, Lane);
         begin
            for Source of Item.Sources loop
               exit when Jobs.Cancel_Requested (Lane);

               begin
                  Run_Item (Item, Source, Watcher);
               exception
                  when others =>
                     Jobs.Report_Error (Lane, Source, Ops.Cannot_Open);
               end;
            end loop;
         end;

         Jobs.Finish (Lane);
      end loop;
   end Worker;
end Explore.Jobs;
