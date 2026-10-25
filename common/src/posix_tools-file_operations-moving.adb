with Posix_Tools.File_Operations.Copying;
with Posix_Tools.File_Operations.Removing;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.File_Operations.Moving is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.File_Kind;

   --  Passes everything on to Inner, except that the conflict over the
   --  move's own target, already settled, is not asked about again when the
   --  move falls back to copying. It notes whether any entry inside was
   --  skipped: its source is all there is of it then, and must stay.
   type Settled_Observer (Inner : not null access Observer'Class; Target_Length : Natural) is
     new Observer with record
      Target  : String (1 .. Target_Length);
      Skipped : Boolean := False;
   end record;

   overriding procedure Report_Error (Self : in out Settled_Observer; Path : String; Error : Operation_Error);
   overriding function Cancelled (Self : in out Settled_Observer) return Boolean;
   overriding procedure Progress (Self : in out Settled_Observer; Path : String; Copied : Long_Long_Integer);
   overriding procedure Finished (Self : in out Settled_Observer; Path : String);
   overriding function Resolve_Conflict
     (Self : in out Settled_Observer; Source, Target : String) return Conflict_Choice;

   --  Whether Path names a directory itself, not a link to one.
   function Is_Directory (Path : String) return Boolean is
     (not FS.Is_Link (Path) and then FS.Kind (Path) = FS.Directory);

   --  Whether the directory Path holds no entries.
   function Is_Empty_Directory (Path : String) return Boolean;

   function Is_Present (Path : String) return Boolean is (FS.Exists (Path) or else FS.Is_Link (Path));

   --  Why the host would not move Source to Target, as near as can be told.
   function Refusal (Source, Target : String) return Operation_Error;

   overriding function Cancelled (Self : in out Settled_Observer) return Boolean is (Self.Inner.Cancelled);

   overriding procedure Finished (Self : in out Settled_Observer; Path : String) is
      pragma Unreferenced (Self, Path);
   begin
      --  The entries copied on the way are not what was moved; the move
      --  reports its source once it is done.
      null;
   end Finished;

   function Is_Empty_Directory (Path : String) return Boolean is
      Empty  : Boolean := True;
      Listed : Boolean;

      procedure Note (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean);

      procedure Note (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean) is
         pragma Unreferenced (Name, Kind);
      begin
         Empty := False;
         Stop := True;
      end Note;

      procedure Each is new FS.For_Each_Listed_Entry (Note);
   begin
      Each (Path, Listed);
      return Listed and then Empty;
   end Is_Empty_Directory;

   procedure Move_By_Copying
     (Source  : String;
      Target  : String;
      Watcher : in out Observer'Class;
      Outcome : out Operation_Outcome)
   is
      procedure Fail (Path : String; Error : Operation_Error);

      procedure Fail (Path : String; Error : Operation_Error) is
      begin
         Outcome := Failed;
         Watcher.Report_Error (Path, Error);
      end Fail;
   begin
      Outcome := Done;

      if not Is_Present (Source) then
         Fail (Source, No_Such_File);
         return;
      end if;

      --  Make way for the copy as rename(2) would replace Target.
      if Is_Directory (Target) then
         if not Is_Directory (Source) then
            Fail (Target, Is_A_Directory);
            return;
         elsif not Is_Empty_Directory (Target) then
            Fail (Target, Directory_Not_Empty);
            return;
         end if;

         begin
            FS.Delete_Directory (Target);
         exception
            when others =>
               Fail (Target, Cannot_Remove);
               return;
         end;
      elsif Is_Present (Target) then
         if Is_Directory (Source) then
            Fail (Target, Not_A_Directory);
            return;
         end if;

         declare
            Removed : Boolean := True;
         begin
            if FS.Is_Link (Target) then
               Removed := FS.Delete_Link (Target);
            else
               FS.Delete_File (Target);
            end if;

            if not Removed then
               Fail (Target, Cannot_Remove);
               return;
            end if;
         exception
            when others =>
               Fail (Target, Cannot_Remove);
               return;
         end;
      end if;

      declare
         Settled : Settled_Observer (Watcher'Access, Target'Length);
         Copied  : Operation_Outcome;
         Removed : Operation_Outcome;
      begin
         Settled.Target := Target;
         Copying.Copy_Path
           (Source,
            Target,
            (Recursive => True, Preserve_Mode => True, Preserve_Links => True),
            Settled,
            Copied);

         --  Whatever was not copied stays where it was; so does the whole
         --  source when an entry in it was skipped, to keep that entry.
         if Copied /= Done then
            Outcome := Copied;
            return;
         elsif Settled.Skipped then
            Outcome := Skipped;
            return;
         end if;

         Removing.Remove_Path (Source, (Recursive => True, Empty_Directories => False), Settled, Removed);

         if Removed = Done then
            Watcher.Finished (Source);
         else
            Outcome := Removed;
         end if;
      end;
   end Move_By_Copying;

   procedure Move_Path
     (Source  : String;
      Target  : String;
      Watcher : in out Observer'Class;
      Outcome : out Operation_Outcome)
   is
   begin
      Outcome := Done;

      if Watcher.Cancelled then
         Outcome := Cancelled;
         return;
      end if;

      if not Is_Present (Source) then
         Outcome := Failed;
         Watcher.Report_Error (Source, No_Such_File);
         return;
      end if;

      if Is_Present (Target)
        and then not Is_Directory (Target)
        and then Watcher.Resolve_Conflict (Source, Target) = Skip
      then
         Outcome := Skipped;
         return;
      end if;

      --  Only a move the host cannot make in one step, as between two file
      --  systems, is made by copying and removing; a refused one is an error,
      --  as rename(2)'s refusal is for mv.
      case FS.Move_Entry (Source, Target) is
         when FS.Moved =>
            Watcher.Finished (Source);
         when FS.Move_Refused =>
            declare
               Error : constant Operation_Error := Refusal (Source, Target);
            begin
               Outcome := Failed;
               Watcher.Report_Error
                 ((if Error in Is_A_Directory | Not_A_Directory | Directory_Not_Empty then Target else Source), Error);
            end;
         when FS.Move_Needs_Copy =>
            Move_By_Copying (Source, Target, Watcher, Outcome);
      end case;
   end Move_Path;

   overriding procedure Progress (Self : in out Settled_Observer; Path : String; Copied : Long_Long_Integer) is
   begin
      Self.Inner.Progress (Path, Copied);
   end Progress;

   function Refusal (Source, Target : String) return Operation_Error is
   begin
      if not Is_Present (Source) then
         return No_Such_File;
      elsif Is_Directory (Target) and then not Is_Directory (Source) then
         return Is_A_Directory;
      elsif Is_Present (Target) and then not Is_Directory (Target) and then Is_Directory (Source) then
         return Not_A_Directory;
      elsif Is_Directory (Target) and then not Is_Empty_Directory (Target) then
         return Directory_Not_Empty;
      else
         return Cannot_Move;
      end if;
   end Refusal;

   overriding procedure Report_Error (Self : in out Settled_Observer; Path : String; Error : Operation_Error) is
   begin
      Self.Inner.Report_Error (Path, Error);
   end Report_Error;

   overriding function Resolve_Conflict
     (Self : in out Settled_Observer; Source, Target : String) return Conflict_Choice
   is
      Choice : Conflict_Choice;
   begin
      if Target = Self.Target then
         return Overwrite;
      end if;

      Choice := Self.Inner.Resolve_Conflict (Source, Target);
      Self.Skipped := Self.Skipped or else Choice = Skip;
      return Choice;
   end Resolve_Conflict;
end Posix_Tools.File_Operations.Moving;
