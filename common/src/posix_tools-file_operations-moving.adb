with Posix_Tools.File_Operations.Copying;
with Posix_Tools.File_Operations.Removing;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.File_Operations.Moving is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.File_Kind;

   --  Passes everything on to Inner, except that the conflict over the
   --  move's own target, already settled, is not asked about again when the
   --  move falls back to copying.
   type Settled_Observer (Inner : not null access Observer'Class; Target_Length : Natural) is
     new Observer with record
      Target : String (1 .. Target_Length);
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
      Ok      : out Boolean)
   is
   begin
      Ok := True;

      if Watcher.Cancelled then
         Ok := False;
         return;
      end if;

      if (FS.Exists (Target) or else FS.Is_Link (Target))
        and then FS.Kind (Target) /= FS.Directory
        and then Watcher.Resolve_Conflict (Source, Target) = Skip
      then
         return;
      end if;

      begin
         FS.Rename (Source, Target);
         Watcher.Finished (Source);
         return;
      exception
         when others =>
            --  Not a move the host can make in one step; copy it instead.
            null;
      end;

      declare
         Settled : Settled_Observer (Watcher'Access, Target'Length);
         Copied  : Boolean;
         Removed : Boolean;
      begin
         Settled.Target := Target;
         Copying.Copy_Path
           (Source,
            Target,
            (Recursive => True, Preserve_Mode => True, Preserve_Links => True),
            Settled,
            Copied);

         if not Copied then
            Ok := False;
            return;
         end if;

         Removing.Remove_Path (Source, (Recursive => True, Empty_Directories => False), Settled, Removed);

         if Removed then
            Watcher.Finished (Source);
         else
            Ok := False;
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
     (Self : in out Settled_Observer; Source, Target : String) return Conflict_Choice is
     (if Target = Self.Target then Overwrite else Self.Inner.Resolve_Conflict (Source, Target));
end Posix_Tools.File_Operations.Moving;
