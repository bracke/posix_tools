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

   --  Path with its symbolic links resolved: through its longest part that
   --  exists, with the rest, which does not yet, after it.
   function Resolved (Path : String) return String;

   function Without_Trailing_Separators (Path : String) return String;

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
      Source_Access_Time       : FS.File_Time;
      Source_Modification_Time : FS.File_Time;
      Source_Times_Available   : Boolean := False;

      procedure Apply_Source_Metadata;

      procedure Capture_Source_Times;

      procedure Copy_Directory;

      --  Source is a symbolic link copied as one.
      procedure Copy_Link;

      --  Source is a file or, links being followed, a link to one; or,
      --  outside a recursive copy, a special file, read for what it holds.
      procedure Copy_Regular;

      procedure Copy_Special;

      --  Remove what Target names, a link itself and not what it points to,
      --  so that the copy can take its place.
      function Delete_Target return Boolean;

      procedure Fail (Path : String; Error : Operation_Error);

      procedure Apply_Source_Metadata is
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

            FS.File_Ownership (Source, Source_User, Source_Group, Source_Available);
            FS.File_Ownership (Target, Target_User, Target_Group, Target_Available);
            if not Source_Available or else not Target_Available then
               return False;
            elsif Source_User = Target_User and then Source_Group = Target_Group then
               return True;
            else
               return FS.Set_Ownership (Target, Source_User, Source_Group);
            end if;
         end Apply_Source_Ownership;
      begin
         if not Options.Preserve_Mode then
            return;
         end if;

         Mode := FS.File_Permission_Bits (Source, Available) mod 8#10000#;

         --  POSIX: an owner that cannot be kept is not an error, but a copy
         --  owned by someone else must not keep the set-user-ID or
         --  set-group-ID bit, which would hand it the wrong privileges.
         if not Apply_Source_Ownership then
            Mode := Mode - ((Mode / 8#2000#) mod 4) * 8#2000#;
         end if;

         if FS.Permissions_Supported
           and then Available
           and then not FS.Set_Permissions (Target, Mode)
         then
            Fail (Target, Cannot_Open);
         end if;

         if Source_Times_Available then
            if not FS.Set_File_Times (Target, Source_Access_Time, Source_Modification_Time) then
               Fail (Target, Cannot_Open);
            end if;
         elsif not FS.Copy_File_Times (Source, Target) then
            Fail (Target, Cannot_Open);
         end if;
      exception
         when others =>
            Fail (Target, Cannot_Open);
      end Apply_Source_Metadata;

      procedure Capture_Source_Times is
      begin
         if Options.Preserve_Mode then
            Source_Times_Available :=
              FS.File_Access_Time_From_File (Source, Source_Access_Time)
              and then FS.File_Time_From_File (Source, Source_Modification_Time);
         end if;
      exception
         when others =>
            Source_Times_Available := False;
      end Capture_Source_Times;

      procedure Copy_Directory is
         Iteration_Ok : Boolean;

         --  Every entry, a link whose target is missing included.
         procedure Copy_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean);

         procedure Copy_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean) is
            pragma Unreferenced (Kind);
            Child : Operation_Outcome;
         begin
            Copy_Entry
              (FS.Child_Path (Source, Name),
               FS.Child_Path (Target, Name),
               Options,
               Behaviour,
               not Options.Preserve_Links,
               Watcher,
               Ancestors,
               Child);
            Outcome := Combined (Outcome, Child);
            Stop := Watcher.Cancelled;
         end Copy_Child;

         procedure For_Each_Child is new FS.For_Each_Listed_Entry (Copy_Child);
      begin
         if not Options.Recursive then
            Fail (Source, Is_A_Directory);
            return;
         end if;

         --  A directory reached again on the way down, as by a link to one
         --  around it, would be copied without end.
         for Ancestor of Ancestors loop
            if FS.Same_File (Ancestor, Source) then
               Fail (Source, File_System_Loop);
               return;
            end if;
         end loop;

         begin
            if Is_Same_Or_Descendant (Source, Target) then
               Fail (Target, Same_File);
               return;
            end if;

            if not FS.Exists (Target) then
               FS.Create_Directory (Target);
            elsif FS.Kind (Target) /= FS.Directory then
               Fail (Target, Not_A_Directory);
               return;
            end if;

            Ancestors.Append (Source);
            begin
               For_Each_Child (Source, Iteration_Ok);
            exception
               when others =>
                  Ancestors.Delete_Last;
                  raise;
            end;
            Ancestors.Delete_Last;

            if not Iteration_Ok then
               Fail (Source, Cannot_Read_Directory);
            elsif Watcher.Cancelled then
               Outcome := Combined (Outcome, Cancelled);
            else
               --  Only once the children are in: a read-only mode would keep
               --  them out, and making them would change the times.
               Apply_Source_Metadata;

               if Outcome = Done then
                  Watcher.Finished (Source);
               end if;
            end if;
         exception
            when others =>
               Fail (Target, Cannot_Open);
         end;
      end Copy_Directory;

      procedure Copy_Link is
         Target_Text : Unbounded_String;
      begin
         if (FS.Is_Link (Target) or else FS.Kind (Target) = FS.Ordinary_File)
           and then Watcher.Resolve_Conflict (Source, Target) = Skip
         then
            Outcome := Skipped;
            return;
         end if;

         if not FS.Read_Link_Target (Source, Target_Text) then
            Fail (Source, Cannot_Open);
            return;
         end if;

         if (FS.Is_Link (Target) or else FS.Kind (Target) = FS.Ordinary_File) and then not Delete_Target then
            Fail (Target, Cannot_Remove);
            return;
         end if;

         if FS.Create_Link (To_String (Target_Text), Target) then
            Watcher.Finished (Source);
         else
            Fail (Target, Cannot_Open);
         end if;
      exception
         when others =>
            Fail (Source, Cannot_Open);
      end Copy_Link;

      procedure Copy_Regular is
         Present     : constant Boolean := FS.Exists (Target) or else FS.Is_Link (Target);
         Copy_Status : FS.Copy_File_Status;

         procedure Report (Copied : Long_Long_Integer; Stop : in out Boolean);

         procedure Report (Copied : Long_Long_Integer; Stop : in out Boolean) is
         begin
            Watcher.Progress (Source, Copied);
            Stop := Watcher.Cancelled;
         end Report;

         procedure Copy is new FS.Copy_Regular_File_With_Progress (Report);
      begin
         if not FS.Exists (Source) and then not FS.Is_Link (Source) then
            Fail (Source, No_Such_File);
            return;
         elsif FS.Exists (Target) and then FS.Same_File (Source, Target) then
            Fail (Target, Same_File);
            return;
         elsif Present and then not FS.Is_Link (Target) and then FS.Kind (Target) = FS.Directory then
            Fail (Target, Is_A_Directory);
            return;
         end if;

         if Present and then Watcher.Resolve_Conflict (Source, Target) = Skip then
            Outcome := Skipped;
            return;
         end if;

         Copy (Source, Target, Copy_Status);

         --  POSIX cp -f: a target that will not open for writing is removed,
         --  and the copy made afresh.
         if Copy_Status = FS.Target_Open_Failed and then Behaviour.Remove_Unwritable and then Present then
            if not Delete_Target then
               Fail (Target, Cannot_Remove);
               return;
            end if;

            Copy (Source, Target, Copy_Status);
         end if;

         case Copy_Status is
            when FS.Copy_Ok =>
               Apply_Source_Metadata;

               if Outcome = Done then
                  Watcher.Finished (Source);
               end if;

            when FS.Copy_Stopped =>
               --  What a stopped copy left is neither the old file nor the
               --  new one; nothing is better than a cut-off copy.
               Outcome := Cancelled;
               begin
                  FS.Delete_File (Target);
               exception
                  when others =>
                     Fail (Target, Cannot_Remove);
               end;

            when FS.Source_Open_Failed | FS.Source_Read_Failed =>
               Fail (Source, Cannot_Read);

            when FS.Target_Open_Failed | FS.Target_Write_Failed =>
               Fail (Target, Cannot_Open);
         end case;
      end Copy_Regular;

      procedure Copy_Special is
         Info    : constant FS.Special_File_Info := FS.Special_File_Info_Of (Source);
         Created : Boolean := False;
      begin
         if FS.Kind (Target) = FS.Directory then
            Fail (Target, Is_A_Directory);
            return;
         elsif (FS.Exists (Target) or else FS.Is_Link (Target))
           and then Watcher.Resolve_Conflict (Source, Target) = Skip
         then
            Outcome := Skipped;
            return;
         elsif (FS.Is_Link (Target) or else FS.Exists (Target)) and then not Delete_Target then
            Fail (Target, Cannot_Remove);
            return;
         end if;

         if Info.Available and then Info.Kind = FS.FIFO then
            Created := FS.Create_FIFO (Target, Info.Mode);
         elsif Info.Available and then Info.Kind in FS.Character_Device | FS.Block_Device then
            Created := FS.Create_Device (Target, Info.Kind, Info.Device, Info.Mode);
         elsif Info.Available and then Info.Kind = FS.Socket then
            Created := FS.Create_Socket (Target, Info.Mode);
         end if;

         if Created then
            Apply_Source_Metadata;
            Watcher.Finished (Source);
         elsif Info.Available
           and then Info.Kind in FS.FIFO | FS.Character_Device | FS.Block_Device | FS.Socket
         then
            Fail (Target, Cannot_Open);
         else
            Fail (Source, Unsupported_Type);
         end if;
      end Copy_Special;

      function Delete_Target return Boolean is
      begin
         if FS.Is_Link (Target) then
            return FS.Delete_Link (Target);
         end if;

         FS.Delete_File (Target);
         return True;
      exception
         when others =>
            return False;
      end Delete_Target;

      procedure Fail (Path : String; Error : Operation_Error) is
      begin
         Outcome := Failed;
         Watcher.Report_Error (Path, Error);
      end Fail;
   begin
      Outcome := Done;

      if Watcher.Cancelled then
         Outcome := Cancelled;
         return;
      end if;

      --  Before the copy reads the source, and so moves its access time.
      Capture_Source_Times;
      if not Follow and then FS.Is_Link (Source) then
         Copy_Link;
      else
         case FS.Kind (Source) is
            when FS.Directory =>
               Copy_Directory;
            when FS.Special_File =>
               if Options.Recursive then
                  Copy_Special;
               else
                  Copy_Regular;
               end if;
            when FS.Missing_File | FS.Ordinary_File =>
               Copy_Regular;
         end case;
      end if;
   end Copy_Entry;

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
   exception
      when others =>
         return Path;
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
