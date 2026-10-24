with Posix_Tools.File_Operations.Copying;
with Posix_Tools.File_Operations.Moving;
with Posix_Tools.File_Operations.Removing;
with Posix_Tools.Host_Adapters.File_System;

package body Explore.Jobs is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Ops renames Posix_Tools.File_Operations;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Ops.Conflict_Choice;

   --  How a job's operations reach the board.
   type Job_Observer (Jobs : not null access Board) is new Ops.Observer with record
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

   function Join (Directory, Name : String) return String is
     (if Directory'Length > 0 and then Directory (Directory'Last) = '/' then Directory & Name
      else Directory & "/" & Name);

   function Name_Of (Path : String) return String;

   --  Run one entry of a job.
   procedure Run_Item (Item : Job; Source : String; Watcher : in out Job_Observer'Class);

   protected body Board is
      procedure Answer (Choice : Conflict_Answer) is
      begin
         if State.Asking then
            Reply := Choice;
            Answered := True;
            State.Asking := False;
            State.Conflict := Unbounded.Null_Unbounded_String;
         end if;
      end Answer;

      procedure Ask (Target : String) is
      begin
         Answered := False;
         State.Asking := True;
         State.Conflict := Unbounded.To_Unbounded_String (Target);
      end Ask;

      procedure Begin_Item (Path : String) is
      begin
         State.Current := Unbounded.To_Unbounded_String (Path);
         State.Copied := 0;
         State.Size := 0;
      end Begin_Item;

      procedure Cancel is
      begin
         if State.Running then
            Cancelling := True;
         end if;
      end Cancel;

      function Cancel_Requested return Boolean is (Cancelling or else Closed);

      procedure Clear_Errors is
      begin
         State.Errors := 0;
         State.Error_Path := Unbounded.Null_Unbounded_String;
      end Clear_Errors;

      procedure End_Item is
      begin
         State.Done := State.Done + 1;
      end End_Item;

      procedure Finish is
      begin
         State.Running := False;
         State.Asking := False;
         State.Current := Unbounded.Null_Unbounded_String;
         State.Completed := State.Completed + 1;
         Cancelling := False;
      end Finish;

      procedure Report_Error (Path : String; Error : Ops.Operation_Error) is
      begin
         State.Errors := State.Errors + 1;
         State.Error_Path := Unbounded.To_Unbounded_String (Path);
         State.Error := Error;
      end Report_Error;

      procedure Report_Progress (Copied, Size : Long_Long_Integer) is
      begin
         State.Copied := Copied;
         State.Size := Size;
      end Report_Progress;

      procedure Shut_Down is
      begin
         Closed := True;
      end Shut_Down;

      procedure Start (Kind : Job_Kind; Total : Natural) is
      begin
         State.Running := True;
         State.Kind := Kind;
         State.Done := 0;
         State.Total := Total;
         Cancelling := False;
      end Start;

      function Status return Snapshot is (State);

      procedure Submit (Item : Job; Accepted : out Boolean) is
      begin
         Accepted := not Closed and then State.Queued < Max_Queued;

         if Accepted then
            Queue.Append (Item);
            State.Queued := State.Queued + 1;
         end if;
      end Submit;

      entry Take (Item : out Job; Closed : out Boolean)
        when Board.Closed or else State.Queued > 0
      is
      begin
         Closed := Board.Closed;

         if Closed then
            Item := (others => <>);
            return;
         end if;

         Item := Queue.First_Element;
         Queue.Delete_First;
         State.Queued := State.Queued - 1;
      end Take;

      entry Wait_Answer (Choice : out Conflict_Answer)
        when Answered or else Cancelling or else Closed
      is
      begin
         --  A job cancelled while it asked leaves the target alone.
         Choice := (if Answered then Reply else Skip_One);
         Answered := False;
         State.Asking := False;
      end Wait_Answer;
   end Board;

   overriding function Cancelled (Self : in out Job_Observer) return Boolean is (Self.Jobs.Cancel_Requested);

   function Destination (Source, Directory : String) return String is
      Name   : constant String := Name_Of (Source);
      Wanted : constant String := Join (Directory, Name);
   begin
      if Wanted /= Source then
         return Wanted;
      end if;

      for N in 1 .. 10_000 loop
         declare
            Image     : constant String := Natural'Image (N);
            Candidate : constant String := Wanted & "_" & Image (Image'First + 1 .. Image'Last);
         begin
            if not FS.Exists (Candidate) and then not FS.Is_Link (Candidate) then
               return Candidate;
            end if;
         end;
      end loop;

      return Wanted;
   end Destination;

   function Name_Of (Path : String) return String is
      Last : Natural := Path'Last;
   begin
      while Last > Path'First and then Path (Last) = '/' loop
         Last := Last - 1;
      end loop;

      for I in reverse Path'First .. Last loop
         if Path (I) = '/' then
            return Path (I + 1 .. Last);
         end if;
      end loop;

      return Path (Path'First .. Last);
   end Name_Of;

   overriding procedure Progress (Self : in out Job_Observer; Path : String; Copied : Long_Long_Integer) is
   begin
      if Unbounded.To_String (Self.Copying) /= Path then
         Self.Copying := Unbounded.To_Unbounded_String (Path);
         Self.Size := FS.Size (Path);
         Self.Jobs.Begin_Item (Path);
      end if;

      Self.Jobs.Report_Progress (Copied, Self.Size);
   end Progress;

   overriding procedure Report_Error (Self : in out Job_Observer; Path : String; Error : Ops.Operation_Error) is
   begin
      Self.Jobs.Report_Error (Path, Error);
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

      Self.Jobs.Ask (Target);
      Self.Jobs.Wait_Answer (Choice);

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
      Ok        : Boolean;
   begin
      Watcher.Jobs.Begin_Item (Source);

      case Item.Kind is
         when Copy_Job =>
            Ops.Copying.Copy_Path
              (Source,
               Destination (Source, Directory),
               (Recursive => True, Preserve_Mode => True, Preserve_Links => True),
               Watcher,
               Ok);
         when Move_Job =>
            --  Moving into the directory it is already in moves nothing.
            if Join (Directory, Name_Of (Source)) /= Source then
               Ops.Moving.Move_Path (Source, Join (Directory, Name_Of (Source)), Watcher, Ok);
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
            Ops.Removing.Remove_Path (Source, (Recursive => True, Empty_Directories => False), Watcher, Ok);
      end case;

      Watcher.Jobs.End_Item;
   end Run_Item;

   task body Worker is
      Item   : Job;
      Closed : Boolean;
   begin
      loop
         Jobs.Take (Item, Closed);
         exit when Closed;
         Jobs.Start (Item.Kind, Natural (Item.Sources.Length));

         declare
            Watcher : Job_Observer (Jobs);
         begin
            for Source of Item.Sources loop
               exit when Jobs.Cancel_Requested;

               begin
                  Run_Item (Item, Source, Watcher);
               exception
                  when others =>
                     Jobs.Report_Error (Source, Ops.Cannot_Open);
               end;
            end loop;
         end;

         Jobs.Finish;
      end loop;
   end Worker;
end Explore.Jobs;
