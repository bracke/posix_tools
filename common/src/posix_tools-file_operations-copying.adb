with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Paths;

package body Posix_Tools.File_Operations.Copying is

   use Ada.Strings.Unbounded;
   use type Posix_Tools.Host_Adapters.File_System.Copy_File_Status;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Posix_Tools.Host_Adapters.File_System.Special_File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   --  The directories a copy is inside of, outermost first.
   package Path_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   --  One entry being copied: what Copy_Entry was given, and how it went.
   type Copy_Job
     (Watcher       : not null access Observer'Class;
      Ancestors     : not null access Path_Vectors.Vector;
      Source_Length : Natural;
      Target_Length : Natural)
   is limited record
      Source                   : String (1 .. Source_Length);
      Target                   : String (1 .. Target_Length);
      Options                  : Copy_Options;
      Behaviour                : Copy_Behaviour;
      Outcome                  : Operation_Outcome := Done;
      Source_Access_Time       : FS.File_Time;
      Source_Modification_Time : FS.File_Time;
      Source_Times_Available   : Boolean := False;
   end record;

   --  Copy Source to Target, as Copy_Path does, inside the directories
   --  Ancestors names. Follow says whether Source is followed if it is a
   --  symbolic link.
   procedure Copy_Entry
     (Source    : String;
      Target    : String;
      Options   : Copy_Options;
      Behaviour : Copy_Behaviour;
      Follow    : Boolean;
      Watcher   : in out Observer'Class;
      Ancestors : in out Path_Vectors.Vector;
      Outcome   : out Operation_Outcome);

   procedure Apply_Source_Metadata (Job : in out Copy_Job);

   procedure Capture_Source_Times (Job : in out Copy_Job);

   procedure Copy_Directory (Job : in out Copy_Job);

   --  Source is a symbolic link copied as one.
   procedure Copy_Link (Job : in out Copy_Job);

   --  Source is a file or, links being followed, a link to one; or,
   --  outside a recursive copy, a special file, read for what it holds.
   procedure Copy_Regular (Job : in out Copy_Job);

   procedure Copy_Special (Job : in out Copy_Job);

   --  Remove what Target names, a link itself and not what it points to,
   --  so that the copy can take its place.
   function Delete_Target (Job : Copy_Job) return Boolean;

   procedure Fail (Job : in out Copy_Job; Path : String; Error : Operation_Error);

   --  Whether Child is Parent or lies inside it, once symbolic links in
   --  either have been resolved; Child need not exist yet.
   function Is_Same_Or_Descendant (Parent, Child : String) return Boolean;

   --  Path with its symbolic links resolved: through its longest part that
   --  exists, with the rest, which does not yet, after it.
   function Resolved (Path : String) return String;

   function Without_Trailing_Separators (Path : String) return String;

   procedure Apply_Source_Metadata (Job : in out Copy_Job) is
      Available : Boolean;
      Mode      : Natural;

      --  Give Target Source's owner and group, and say whether it has
      --  them now: a copy by anyone but the superuser usually cannot.
      function Apply_Source_Ownership return Boolean;

      function Apply_Source_Ownership return Boolean is
         Source_User      : Natural;
         Source_Group     : Natural;
         Source_Available : Boolean;
         Target_User      : Natural;
         Target_Group     : Natural;
         Target_Available : Boolean;
      begin
         if not FS.Ownership_Supported then
            return True;
         end if;

         FS.File_Ownership (Job.Source, Source_User, Source_Group, Source_Available);
         FS.File_Ownership (Job.Target, Target_User, Target_Group, Target_Available);
         if not Source_Available or else not Target_Available then
            return False;
         elsif Source_User = Target_User and then Source_Group = Target_Group then
            return True;
         else
            return FS.Set_Ownership (Job.Target, Source_User, Source_Group);
         end if;
      end Apply_Source_Ownership;
   begin
      if not Job.Options.Preserve_Mode then
         return;
      end if;

      Mode := FS.File_Permission_Bits (Job.Source, Available) mod 8#10000#;

      --  POSIX: an owner that cannot be kept is not an error, but a copy
      --  owned by someone else must not keep the set-user-ID or
      --  set-group-ID bit, which would hand it the wrong privileges.
      if not Apply_Source_Ownership then
         Mode := Mode - ((Mode / 8#2000#) mod 4) * 8#2000#;
      end if;

      --  Times first: where a read-only mode is an ACL, as on Windows, it
      --  also forbids setting them.
      if Job.Source_Times_Available then
         if not FS.Set_File_Times (Job.Target, Job.Source_Access_Time, Job.Source_Modification_Time) then
            Fail (Job, Job.Target, Cannot_Open);
         end if;
      elsif not FS.Copy_File_Times (Job.Source, Job.Target) then
         Fail (Job, Job.Target, Cannot_Open);
      end if;

      if FS.Permissions_Supported
        and then Available
        and then not FS.Set_Permissions (Job.Target, Mode)
      then
         Fail (Job, Job.Target, Cannot_Open);
      end if;
   end Apply_Source_Metadata;

   procedure Capture_Source_Times (Job : in out Copy_Job) is
   begin
      if Job.Options.Preserve_Mode then
         Job.Source_Times_Available :=
           FS.File_Access_Time_From_File (Job.Source, Job.Source_Access_Time)
           and then FS.File_Time_From_File (Job.Source, Job.Source_Modification_Time);
      end if;
   end Capture_Source_Times;

   procedure Copy_Directory (Job : in out Copy_Job) is
      Iteration_Ok : Boolean;

      --  Every entry, a link whose target is missing included.
      procedure Copy_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean);

      procedure Copy_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean) is
         pragma Unreferenced (Kind);
         Child : Operation_Outcome;
      begin
         Copy_Entry
           (FS.Child_Path (Job.Source, Name),
            FS.Child_Path (Job.Target, Name),
            Job.Options,
            Job.Behaviour,
            not Job.Options.Preserve_Links,
            Job.Watcher.all,
            Job.Ancestors.all,
            Child);
         Job.Outcome := Combined (Job.Outcome, Child);
         Stop := Job.Watcher.Cancelled;
      end Copy_Child;

      procedure For_Each_Child is new FS.For_Each_Listed_Entry (Copy_Child);
   begin
      if not Job.Options.Recursive then
         Fail (Job, Job.Source, Is_A_Directory);
         return;
      end if;

      --  A directory reached again on the way down, as by a link to one
      --  around it, would be copied without end.
      for Ancestor of Job.Ancestors.all loop
         if FS.Same_File (Ancestor, Job.Source) then
            Fail (Job, Job.Source, File_System_Loop);
            return;
         end if;
      end loop;

      if Is_Same_Or_Descendant (Job.Source, Job.Target) then
         Fail (Job, Job.Target, Same_File);
         return;
      end if;

      if not FS.Exists (Job.Target) then
         if not FS.Create_Directory (Job.Target) then
            Fail (Job, Job.Target, Cannot_Open);
            return;
         end if;
      elsif FS.Kind (Job.Target) /= FS.Directory then
         Fail (Job, Job.Target, Not_A_Directory);
         return;
      end if;

      Job.Ancestors.Append (Job.Source);
      For_Each_Child (Job.Source, Iteration_Ok);
      Job.Ancestors.Delete_Last;

      if not Iteration_Ok then
         Fail (Job, Job.Source, Cannot_Read_Directory);
      elsif Job.Watcher.Cancelled then
         Job.Outcome := Combined (Job.Outcome, Cancelled);
      else
         --  Only once the children are in: a read-only mode would keep
         --  them out, and making them would change the times.
         Apply_Source_Metadata (Job);

         if Job.Outcome = Done then
            Job.Watcher.Finished (Job.Source);
         end if;
      end if;
   end Copy_Directory;

   procedure Copy_Entry
     (Source    : String;
      Target    : String;
      Options   : Copy_Options;
      Behaviour : Copy_Behaviour;
      Follow    : Boolean;
      Watcher   : in out Observer'Class;
      Ancestors : in out Path_Vectors.Vector;
      Outcome   : out Operation_Outcome)
   is
      Job : Copy_Job (Watcher'Access, Ancestors'Access, Source'Length, Target'Length);
   begin
      if Watcher.Cancelled then
         Outcome := Cancelled;
         return;
      end if;

      Job.Source := Source;
      Job.Target := Target;
      Job.Options := Options;
      Job.Behaviour := Behaviour;

      --  Before the copy reads the source, and so moves its access time.
      Capture_Source_Times (Job);
      if not Follow and then FS.Is_Link (Source) then
         Copy_Link (Job);
      else
         case FS.Kind (Source) is
            when FS.Directory =>
               Copy_Directory (Job);
            when FS.Special_File =>
               if Options.Recursive then
                  Copy_Special (Job);
               else
                  Copy_Regular (Job);
               end if;
            when FS.Missing_File | FS.Ordinary_File =>
               Copy_Regular (Job);
         end case;
      end if;

      Outcome := Job.Outcome;
   end Copy_Entry;

   procedure Copy_Link (Job : in out Copy_Job) is
      Target_Text : Unbounded_String;
   begin
      if (FS.Is_Link (Job.Target) or else FS.Kind (Job.Target) = FS.Ordinary_File)
        and then Job.Watcher.Resolve_Conflict (Job.Source, Job.Target) = Skip
      then
         Job.Outcome := Skipped;
         return;
      end if;

      if not FS.Read_Link_Target (Job.Source, Target_Text) then
         Fail (Job, Job.Source, Cannot_Open);
         return;
      end if;

      if (FS.Is_Link (Job.Target) or else FS.Kind (Job.Target) = FS.Ordinary_File)
        and then not Delete_Target (Job)
      then
         Fail (Job, Job.Target, Cannot_Remove);
         return;
      end if;

      if FS.Create_Link (To_String (Target_Text), Job.Target) then
         Job.Watcher.Finished (Job.Source);
      else
         Fail (Job, Job.Target, Cannot_Open);
      end if;
   end Copy_Link;

   procedure Copy_Path
     (Source    : String;
      Target    : String;
      Options   : Copy_Options;
      Watcher   : in out Observer'Class;
      Outcome   : out Operation_Outcome;
      Behaviour : Copy_Behaviour := (others => <>))
   is
      Ancestors : Path_Vectors.Vector;
   begin
      Copy_Entry
        (Source,
         Target,
         Options,
         Behaviour,
         not Options.Preserve_Links or else Behaviour.Follow_Source_Link,
         Watcher,
         Ancestors,
         Outcome);
   end Copy_Path;

   procedure Copy_Regular (Job : in out Copy_Job) is
      Present     : constant Boolean := FS.Exists (Job.Target) or else FS.Is_Link (Job.Target);
      Copy_Status : FS.Copy_File_Status;

      procedure Report (Copied : Long_Long_Integer; Stop : in out Boolean);

      procedure Report (Copied : Long_Long_Integer; Stop : in out Boolean) is
      begin
         Job.Watcher.Progress (Job.Source, Copied);
         Stop := Job.Watcher.Cancelled;
      end Report;

      procedure Copy is new FS.Copy_Regular_File_With_Progress (Report);
   begin
      if not FS.Exists (Job.Source) and then not FS.Is_Link (Job.Source) then
         Fail (Job, Job.Source, No_Such_File);
         return;
      elsif FS.Exists (Job.Target) and then FS.Same_File (Job.Source, Job.Target) then
         Fail (Job, Job.Target, Same_File);
         return;
      elsif Present and then not FS.Is_Link (Job.Target) and then FS.Kind (Job.Target) = FS.Directory then
         Fail (Job, Job.Target, Is_A_Directory);
         return;
      end if;

      if Present and then Job.Watcher.Resolve_Conflict (Job.Source, Job.Target) = Skip then
         Job.Outcome := Skipped;
         return;
      end if;

      Copy (Job.Source, Job.Target, Copy_Status);

      --  POSIX cp -f: a target that will not open for writing is removed,
      --  and the copy made afresh.
      if Copy_Status = FS.Target_Open_Failed and then Job.Behaviour.Remove_Unwritable and then Present then
         if not Delete_Target (Job) then
            Fail (Job, Job.Target, Cannot_Remove);
            return;
         end if;

         Copy (Job.Source, Job.Target, Copy_Status);
      end if;

      case Copy_Status is
         when FS.Copy_Ok =>
            Apply_Source_Metadata (Job);

            if Job.Outcome = Done then
               Job.Watcher.Finished (Job.Source);
            end if;

         when FS.Copy_Stopped =>
            --  What a stopped copy left is neither the old file nor the
            --  new one; nothing is better than a cut-off copy.
            Job.Outcome := Cancelled;
            if not FS.Delete_File (Job.Target) then
               Fail (Job, Job.Target, Cannot_Remove);
            end if;

         when FS.Source_Open_Failed | FS.Source_Read_Failed =>
            Fail (Job, Job.Source, Cannot_Read);

         when FS.Target_Open_Failed | FS.Target_Write_Failed =>
            Fail (Job, Job.Target, Cannot_Open);
      end case;
   end Copy_Regular;

   procedure Copy_Special (Job : in out Copy_Job) is
      Info    : constant FS.Special_File_Info := FS.Special_File_Info_Of (Job.Source);
      Created : Boolean := False;
   begin
      if FS.Kind (Job.Target) = FS.Directory then
         Fail (Job, Job.Target, Is_A_Directory);
         return;
      elsif (FS.Exists (Job.Target) or else FS.Is_Link (Job.Target))
        and then Job.Watcher.Resolve_Conflict (Job.Source, Job.Target) = Skip
      then
         Job.Outcome := Skipped;
         return;
      elsif (FS.Is_Link (Job.Target) or else FS.Exists (Job.Target)) and then not Delete_Target (Job) then
         Fail (Job, Job.Target, Cannot_Remove);
         return;
      end if;

      if Info.Available and then Info.Kind = FS.FIFO then
         Created := FS.Create_FIFO (Job.Target, Info.Mode);
      elsif Info.Available and then Info.Kind in FS.Character_Device | FS.Block_Device then
         Created := FS.Create_Device (Job.Target, Info.Kind, Info.Device, Info.Mode);
      elsif Info.Available and then Info.Kind = FS.Socket then
         Created := FS.Create_Socket (Job.Target, Info.Mode);
      end if;

      if Created then
         Apply_Source_Metadata (Job);
         Job.Watcher.Finished (Job.Source);
      elsif Info.Available
        and then Info.Kind in FS.FIFO | FS.Character_Device | FS.Block_Device | FS.Socket
      then
         Fail (Job, Job.Target, Cannot_Open);
      else
         Fail (Job, Job.Source, Unsupported_Type);
      end if;
   end Copy_Special;

   function Delete_Target (Job : Copy_Job) return Boolean is
     (if FS.Is_Link (Job.Target) then FS.Delete_Link (Job.Target) else FS.Delete_File (Job.Target));

   procedure Fail (Job : in out Copy_Job; Path : String; Error : Operation_Error) is
   begin
      Job.Outcome := Failed;
      Job.Watcher.Report_Error (Path, Error);
   end Fail;

   function Is_Same_Or_Descendant (Parent, Child : String) return Boolean is
      Parent_Full : constant String := Without_Trailing_Separators (Resolved (Parent));
      Child_Full  : constant String := Without_Trailing_Separators (Resolved (Child));
   begin
      if Child_Full = Parent_Full then
         return True;
      elsif Child_Full'Length <= Parent_Full'Length then
         return False;
      elsif Child_Full (Child_Full'First .. Child_Full'First + Parent_Full'Length - 1) /= Parent_Full then
         return False;
      elsif Parent_Full'Length > 0 and then Parent_Full (Parent_Full'Last) in '/' | '\' then
         --  The root, which keeps its separator.
         return True;
      else
         return Child_Full (Child_Full'First + Parent_Full'Length) in '/' | '\';
      end if;
   end Is_Same_Or_Descendant;

   function Resolved (Path : String) return String is
      Real : constant String := (if Path = "" then "" else FS.Real_Path (Path));
   begin
      if Real /= "" then
         return Real;
      end if;

      declare
         Parent : constant String := Posix_Tools.Paths.Dirname (Path);
         Name   : constant String := Posix_Tools.Paths.Basename (Path);
      begin
         if Parent = Path or else Name = "" then
            --  Nothing left to resolve.
            return Path;
         end if;

         return FS.Child_Path (Resolved (Parent), Name);
      end;
   end Resolved;

   function Without_Trailing_Separators (Path : String) return String is
      Last : Natural := Path'Last;
   begin
      while Last > Path'First and then Path (Last) in '/' | '\' loop
         Last := Last - 1;
      end loop;

      return Path (Path'First .. Last);
   end Without_Trailing_Separators;
end Posix_Tools.File_Operations.Copying;
