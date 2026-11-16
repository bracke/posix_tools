with Posix_Tools.File_Operations.Copying;
with Posix_Tools.File_Operations.Removing;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.File_Operations.Moving is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.Entry_Kind;

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

   procedure Move_By_Copying
     (Source  : String;
      Target  : String;
      Watcher : in out Observer'Class;
      Outcome : out Operation_Outcome)
   is
      Source_Class : constant FS.Entry_Kind := FS.Entry_Kind_Of (Source);
      Target_Class : constant FS.Entry_Kind := FS.Entry_Kind_Of (Target);

      procedure Fail (Path : String; Error : Operation_Error);

      procedure Fail (Path : String; Error : Operation_Error) is
      begin
         Outcome := Failed;
         Watcher.Report_Error (Path, Error);
      end Fail;
   begin
      Outcome := Done;

      if Source_Class = FS.Entry_Error then
         Fail (Source, Cannot_Read);
         return;
      elsif Target_Class = FS.Entry_Error then
         Fail (Target, Cannot_Read);
         return;
      elsif Source_Class = FS.Entry_Missing then
         Fail (Source, No_Such_File);
         return;
      end if;

      --  Make way for the copy as rename(2) would replace Target.
      if Target_Class = FS.Entry_Directory then
         if Source_Class /= FS.Entry_Directory then
            Fail (Target, Is_A_Directory);
            return;
         elsif not Is_Empty_Directory (Target) then
            Fail (Target, Directory_Not_Empty);
            return;
         end if;

         if not FS.Delete_Directory (Target) then
            Fail (Target, Cannot_Remove);
            return;
         end if;
      elsif Target_Class /= FS.Entry_Missing then
         if Source_Class = FS.Entry_Directory then
            Fail (Target, Not_A_Directory);
            return;
         end if;

         if not
           (if Target_Class = FS.Entry_Link
            then FS.Delete_Link (Target)
            else FS.Delete_File (Target))
         then
            Fail (Target, Cannot_Remove);
            return;
         end if;
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
      Source_Class : FS.Entry_Kind;
      Target_Class : FS.Entry_Kind;
   begin
      Outcome := Done;

      if Watcher.Cancelled then
         Outcome := Cancelled;
         return;
      end if;

      Source_Class := FS.Entry_Kind_Of (Source);
      Target_Class := FS.Entry_Kind_Of (Target);

      if Source_Class = FS.Entry_Error then
         Outcome := Failed;
         Watcher.Report_Error (Source, Cannot_Read);
         return;
      elsif Target_Class = FS.Entry_Error then
         Outcome := Failed;
         Watcher.Report_Error (Target, Cannot_Read);
         return;
      elsif Source_Class = FS.Entry_Missing then
         Outcome := Failed;
         Watcher.Report_Error (Source, No_Such_File);
         return;
      end if;

      if Target_Class not in FS.Entry_Missing | FS.Entry_Directory
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
      Source_Class : constant FS.Entry_Kind := FS.Entry_Kind_Of (Source);
      Target_Class : constant FS.Entry_Kind := FS.Entry_Kind_Of (Target);
   begin
      if Source_Class = FS.Entry_Error or else Target_Class = FS.Entry_Error then
         return Cannot_Read;
      elsif Source_Class = FS.Entry_Missing then
         return No_Such_File;
      elsif Target_Class = FS.Entry_Directory and then Source_Class /= FS.Entry_Directory then
         return Is_A_Directory;
      elsif Target_Class not in FS.Entry_Missing | FS.Entry_Directory
        and then Source_Class = FS.Entry_Directory
      then
         return Not_A_Directory;
      elsif Target_Class = FS.Entry_Directory and then not Is_Empty_Directory (Target) then
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
