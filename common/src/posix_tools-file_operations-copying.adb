with Ada.Strings.Unbounded;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.File_Operations.Copying is

   use Ada.Strings.Unbounded;
   use type Posix_Tools.Host_Adapters.File_System.Copy_File_Status;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Posix_Tools.Host_Adapters.File_System.Special_File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   function Join_Path (Directory, Leaf : String) return String is
     (if Directory = "" or else Directory (Directory'Last) = '/' then Directory & Leaf else Directory & "/" & Leaf);

   function Full_Path_Or_Raw (Path : String) return String;

   function Without_Trailing_Separators (Path : String) return String;

   procedure Copy_Path
     (Source   : String;
      Target   : String;
      Options  : Copy_Options;
      Watcher  : in out Observer'Class;
      Ok       : out Boolean)
   is
      Recursive      : Boolean renames Options.Recursive;
      Preserve_Mode  : Boolean renames Options.Preserve_Mode;
      Preserve_Links : Boolean renames Options.Preserve_Links;

      Source_Access_Time       : FS.File_Time;
      Source_Modification_Time : FS.File_Time;
      Source_Times_Available   : Boolean := False;

      procedure Apply_Source_Metadata;

      procedure Capture_Source_Times;

      procedure Apply_Source_Metadata is
         Available : Boolean;
         Mode      : constant Natural := FS.File_Permission_Bits (Source, Available);

         procedure Apply_Source_Ownership;

         procedure Apply_Source_Ownership is
            Source_User      : Natural;
            Source_Group     : Natural;
            Source_Available : Boolean;
            Target_User      : Natural;
            Target_Group     : Natural;
            Target_Available : Boolean;
         begin
            if not Preserve_Mode or else not FS.Ownership_Supported then
               return;
            end if;

            FS.File_Ownership (Source, Source_User, Source_Group, Source_Available);
            FS.File_Ownership (Target, Target_User, Target_Group, Target_Available);
            if Source_Available
              and then Target_Available
              and then (Source_User /= Target_User or else Source_Group /= Target_Group)
              and then not FS.Set_Ownership (Target, Source_User, Source_Group)
            then
               Ok := False;
               Watcher.Report_Error (Target, Cannot_Open);
            end if;
         end Apply_Source_Ownership;
      begin
         Apply_Source_Ownership;

         if Preserve_Mode
           and then FS.Permissions_Supported
           and then Available
           and then not FS.Set_Permissions (Target, Mode mod 8#1000#)
         then
            Ok := False;
            Watcher.Report_Error (Target, Cannot_Open);
         end if;

         if Preserve_Mode then
            if Source_Times_Available then
               if not FS.Set_File_Times (Target, Source_Access_Time, Source_Modification_Time) then
                  Ok := False;
                  Watcher.Report_Error (Target, Cannot_Open);
               end if;
            elsif not FS.Copy_File_Times (Source, Target) then
               Ok := False;
               Watcher.Report_Error (Target, Cannot_Open);
            end if;
         end if;
      exception
         when others =>
            Ok := False;
            Watcher.Report_Error (Target, Cannot_Open);
      end Apply_Source_Metadata;

      procedure Capture_Source_Times is
      begin
         if Preserve_Mode then
            Source_Times_Available :=
              FS.File_Access_Time_From_File (Source, Source_Access_Time)
              and then FS.File_Time_From_File (Source, Source_Modification_Time);
         end if;
      exception
         when others =>
            Source_Times_Available := False;
      end Capture_Source_Times;

   begin
      Ok := True;

      if Watcher.Cancelled then
         Ok := False;
         return;
      end if;

      Capture_Source_Times;
      if Preserve_Links and then FS.Is_Link (Source) then
         declare
            Target_Text : Unbounded_String;
         begin
            if (FS.Is_Link (Target) or else FS.Kind (Target) = FS.Ordinary_File)
              and then Watcher.Resolve_Conflict (Source, Target) = Skip
            then
               return;
            end if;

            if FS.Read_Link_Target (Source, Target_Text) then
               if FS.Is_Link (Target) then
                  Ok := FS.Delete_Link (Target);
               elsif FS.Kind (Target) = FS.Ordinary_File
               then
                  FS.Delete_File (Target);
               end if;

               if Ok and then FS.Create_Link (To_String (Target_Text), Target) then
                  Watcher.Finished (Source);
                  return;
               end if;
            end if;

            Ok := False;
            Watcher.Report_Error (Source, Cannot_Open);
            return;
         exception
            when others =>
               Ok := False;
               Watcher.Report_Error (Source, Cannot_Open);
               return;
         end;
      end if;

      if FS.Kind (Source) = FS.Directory
      then
         if not Recursive then
            Ok := False;
            Watcher.Report_Error (Source, Is_A_Directory);
            return;
         end if;

         begin
            if Is_Same_Or_Descendant (Source, Target) then
               Ok := False;
               Watcher.Report_Error (Target, Same_File);
               return;
            end if;

            if not FS.Exists (Target) then
               FS.Create_Directory (Target);
            elsif FS.Kind (Target) /= FS.Directory then
               Ok := False;
               Watcher.Report_Error (Target, Not_A_Directory);
               return;
            end if;
            Apply_Source_Metadata;

            declare
               Iteration_Ok : Boolean;

               --  Every entry, a link whose target is missing included.
               procedure Copy_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean);

               procedure Copy_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean) is
                  pragma Unreferenced (Kind);
                  Child_Ok : Boolean;
               begin
                  Copy_Path (Join_Path (Source, Name), Join_Path (Target, Name), Options, Watcher, Child_Ok);
                  Ok := Ok and Child_Ok;
                  Stop := Watcher.Cancelled;
               end Copy_Child;

               procedure For_Each_Child is new FS.For_Each_Listed_Entry (Copy_Child);
            begin
               For_Each_Child (Source, Iteration_Ok);
               if not Iteration_Ok then
                  Ok := False;
                  Watcher.Report_Error (Source, Cannot_Read_Directory);
               elsif Watcher.Cancelled then
                  Ok := False;
               elsif Ok then
                  Watcher.Finished (Source);
               end if;
            end;
            return;
         exception
            when others =>
               Ok := False;
               Watcher.Report_Error (Target, Cannot_Open);
               return;
         end;
      end if;

      if FS.Kind (Source) = FS.Special_File
      then
         declare
            Info    : constant FS.Special_File_Info := FS.Special_File_Info_Of (Source);
            Created : Boolean := False;
         begin
            if FS.Kind (Target) = FS.Directory then
               Ok := False;
               Watcher.Report_Error (Target, Not_A_Directory);
               return;
            elsif (FS.Exists (Target) or else FS.Is_Link (Target))
              and then Watcher.Resolve_Conflict (Source, Target) = Skip
            then
               return;
            elsif FS.Exists (Target) then
               if FS.Is_Link (Target) then
                  Ok := FS.Delete_Link (Target);
               else
                  begin
                     FS.Delete_File (Target);
                     Ok := True;
                  exception
                     when others =>
                        Ok := False;
                  end;
               end if;

               if not Ok then
                  Watcher.Report_Error (Target, Cannot_Open);
                  return;
               end if;
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
               Ok := False;
               Watcher.Report_Error (Target, Cannot_Open);
            else
               Ok := False;
               Watcher.Report_Error (Source, Unsupported_Type);
            end if;
         end;
         return;
      end if;

      if FS.Exists (Target) and then FS.Same_File (Source, Target) then
         Ok := False;
         Watcher.Report_Error (Target, Same_File);
         return;
      end if;

      if (FS.Exists (Target) or else FS.Is_Link (Target))
        and then FS.Kind (Target) /= FS.Directory
        and then Watcher.Resolve_Conflict (Source, Target) = Skip
      then
         return;
      end if;

      declare
         Copy_Status : FS.Copy_File_Status;

         procedure Report (Copied : Long_Long_Integer; Stop : in out Boolean);

         procedure Report (Copied : Long_Long_Integer; Stop : in out Boolean) is
         begin
            Watcher.Progress (Source, Copied);
            Stop := Watcher.Cancelled;
         end Report;

         procedure Copy is new FS.Copy_Regular_File_With_Progress (Report);
      begin
         Copy (Source, Target, Copy_Status);
         Ok := Copy_Status = FS.Copy_Ok;
         case Copy_Status is
            when FS.Copy_Ok =>
               Apply_Source_Metadata;

               if Ok then
                  Watcher.Finished (Source);
               end if;

            when FS.Copy_Stopped =>
               null;

            when FS.Source_Open_Failed | FS.Source_Read_Failed =>
               Watcher.Report_Error (Source, Cannot_Read);

            when FS.Target_Open_Failed | FS.Target_Write_Failed =>
               Watcher.Report_Error (Target, Cannot_Open);
         end case;
      end;
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
