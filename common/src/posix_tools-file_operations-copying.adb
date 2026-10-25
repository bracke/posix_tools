with Ada.Strings.Unbounded;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.File_Operations.Copying is

   use Ada.Strings.Unbounded;
   use type Posix_Tools.Host_Adapters.File_System.Copy_File_Status;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Posix_Tools.Host_Adapters.File_System.Special_File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   function Full_Path_Or_Raw (Path : String) return String;

   function Without_Trailing_Separators (Path : String) return String;

   procedure Copy_Path
     (Source  : String;
      Target  : String;
      Options : Copy_Options;
      Watcher : in out Observer'Class;
      Outcome : out Operation_Outcome)
   is
      Source_Access_Time       : FS.File_Time;
      Source_Modification_Time : FS.File_Time;
      Source_Times_Available   : Boolean := False;

      procedure Apply_Source_Metadata;

      procedure Capture_Source_Times;

      procedure Copy_Directory;

      --  Source is a symbolic link copied as one.
      procedure Copy_Link;

      --  Source is a file or, links being followed, a link to one.
      procedure Copy_Regular;

      procedure Copy_Special;

      --  Remove what Target names, a link itself and not what it points to,
      --  so that the copy can take its place.
      function Delete_Target return Boolean;

      procedure Fail (Path : String; Error : Operation_Error);

      procedure Apply_Source_Metadata is
         Available : Boolean;
         Mode      : Natural;

         procedure Apply_Source_Ownership;

         procedure Apply_Source_Ownership is
            Source_User      : Natural;
            Source_Group     : Natural;
            Source_Available : Boolean;
            Target_User      : Natural;
            Target_Group     : Natural;
            Target_Available : Boolean;
         begin
            if not FS.Ownership_Supported then
               return;
            end if;

            FS.File_Ownership (Source, Source_User, Source_Group, Source_Available);
            FS.File_Ownership (Target, Target_User, Target_Group, Target_Available);
            if Source_Available
              and then Target_Available
              and then (Source_User /= Target_User or else Source_Group /= Target_Group)
              and then not FS.Set_Ownership (Target, Source_User, Source_Group)
            then
               Fail (Target, Cannot_Open);
            end if;
         end Apply_Source_Ownership;
      begin
         if not Options.Preserve_Mode then
            return;
         end if;

         Mode := FS.File_Permission_Bits (Source, Available);
         Apply_Source_Ownership;

         if FS.Permissions_Supported
           and then Available
           and then not FS.Set_Permissions (Target, Mode mod 8#1000#)
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
            Copy_Path (FS.Child_Path (Source, Name), FS.Child_Path (Target, Name), Options, Watcher, Child);
            Outcome := Combined (Outcome, Child);
            Stop := Watcher.Cancelled;
         end Copy_Child;

         procedure For_Each_Child is new FS.For_Each_Listed_Entry (Copy_Child);
      begin
         if not Options.Recursive then
            Fail (Source, Is_A_Directory);
            return;
         end if;

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

            For_Each_Child (Source, Iteration_Ok);
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
         Copy_Status : FS.Copy_File_Status;

         procedure Report (Copied : Long_Long_Integer; Stop : in out Boolean);

         procedure Report (Copied : Long_Long_Integer; Stop : in out Boolean) is
         begin
            Watcher.Progress (Source, Copied);
            Stop := Watcher.Cancelled;
         end Report;

         procedure Copy is new FS.Copy_Regular_File_With_Progress (Report);
      begin
         if FS.Exists (Target) and then FS.Same_File (Source, Target) then
            Fail (Target, Same_File);
            return;
         end if;

         if (FS.Exists (Target) or else FS.Is_Link (Target))
           and then FS.Kind (Target) /= FS.Directory
           and then Watcher.Resolve_Conflict (Source, Target) = Skip
         then
            Outcome := Skipped;
            return;
         end if;

         Copy (Source, Target, Copy_Status);
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
            Fail (Target, Not_A_Directory);
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

      Capture_Source_Times;
      if Options.Preserve_Links and then FS.Is_Link (Source) then
         Copy_Link;
      else
         case FS.Kind (Source) is
            when FS.Directory =>
               Copy_Directory;
            when FS.Special_File =>
               Copy_Special;
            when FS.Missing_File | FS.Ordinary_File =>
               Copy_Regular;
         end case;
      end if;
   end Copy_Path;

   function Full_Path_Or_Raw (Path : String) return String is
   begin
      return FS.Full_Name (Path);
   exception
      when others =>
         return Path;
   end Full_Path_Or_Raw;

   function Is_Same_Or_Descendant (Parent, Child : String) return Boolean is
      Parent_Full : constant String := Without_Trailing_Separators (Full_Path_Or_Raw (Parent));
      Child_Full  : constant String := Without_Trailing_Separators (Full_Path_Or_Raw (Child));
   begin
      if Child_Full = Parent_Full then
         return True;
      elsif Child_Full'Length <= Parent_Full'Length then
         return False;
      elsif Child_Full (Child_Full'First .. Child_Full'First + Parent_Full'Length - 1) /= Parent_Full then
         return False;
      else
         return Child_Full (Child_Full'First + Parent_Full'Length) in '/' | '\';
      end if;
   end Is_Same_Or_Descendant;

   function Without_Trailing_Separators (Path : String) return String is
      Last : Natural := Path'Last;
   begin
      while Last > Path'First and then Path (Last) in '/' | '\' loop
         Last := Last - 1;
      end loop;

      return Path (Path'First .. Last);
   end Without_Trailing_Separators;

end Posix_Tools.File_Operations.Copying;
