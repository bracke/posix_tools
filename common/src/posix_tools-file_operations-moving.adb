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

   overriding function Cancelled (Self : in out Settled_Observer) return Boolean is (Self.Inner.Cancelled);

   overriding procedure Finished (Self : in out Settled_Observer; Path : String) is
      pragma Unreferenced (Self, Path);
   begin
      --  The entries copied on the way are not what was moved; the move
      --  reports its source once it is done.
      null;
   end Finished;

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

      if (FS.Exists (Target) or else FS.Is_Link (Target))
        and then FS.Kind (Target) /= FS.Directory
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
            return;
         when FS.Move_Refused =>
            Outcome := Failed;
            Watcher.Report_Error (Source, Cannot_Move);
            return;
         when FS.Move_Needs_Copy =>
            null;
      end case;

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
   end Move_Path;

   overriding procedure Progress (Self : in out Settled_Observer; Path : String; Copied : Long_Long_Integer) is
   begin
      Self.Inner.Progress (Path, Copied);
   end Progress;

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
