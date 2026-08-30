with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.File_Helpers.Copying is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Host_Adapters.File_System.Copy_File_Status;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Posix_Tools.Host_Adapters.File_System.Special_File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   function Full_Path_Or_Raw (Path : String) return String is
   begin
      return FS.Full_Name (Path);
   exception
      when others =>
         return Path;
   end Full_Path_Or_Raw;

   function Without_Trailing_Separators (Path : String) return String is
      Last : Natural := Path'Last;
   begin
      while Last > Path'First and then Path (Last) in '/' | '\' loop
         Last := Last - 1;
      end loop;

      return Path (Path'First .. Last);
   end Without_Trailing_Separators;

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

   procedure Copy_Path
     (Context        : in out Posix_Tools.Commands.Contexts.Context'Class;
      Source         : String;
      Target         : String;
      Recursive      : Boolean;
      Preserve_Mode  : Boolean;
      Preserve_Links : Boolean;
      Ok             : out Boolean)
   is
      Source_Access_Time       : FS.File_Time;
      Source_Modification_Time : FS.File_Time;
      Source_Times_Available   : Boolean := False;

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

      procedure Apply_Source_Metadata is
         Available : Boolean;
         Mode      : constant Natural := FS.File_Permission_Bits (Source, Available);

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
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
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
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end if;

         if Preserve_Mode then
            if Source_Times_Available then
               if not FS.Set_File_Times (Target, Source_Access_Time, Source_Modification_Time) then
                  Ok := False;
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               end if;
            elsif not FS.Copy_File_Times (Source, Target) then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            end if;
         end if;
      exception
         when others =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end Apply_Source_Metadata;
   begin
      Ok := True;
      Capture_Source_Times;
      if Preserve_Links and then FS.Is_Link (Source) then
         declare
            Target_Text : Unbounded_String;
         begin
            if FS.Read_Link_Target (Source, Target_Text) then
               if FS.Is_Link (Target) then
                  Ok := FS.Delete_Link (Target);
               elsif FS.Kind (Target) = FS.Ordinary_File
               then
                  FS.Delete_File (Target);
               end if;

               if Ok and then FS.Create_Link (To_String (Target_Text), Target) then
                  return;
               end if;
            end if;

            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Source, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            return;
         exception
            when others =>
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Source, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               return;
         end;
      end if;

      if FS.Kind (Source) = FS.Directory
      then
         if not Recursive then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Source, "posix_tools.diagnostic.file.is_directory", "is a directory");
            return;
         end if;

         begin
            if Is_Same_Or_Descendant (Source, Target) then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.same_file", "source and destination are the same file");
               return;
            end if;

            if not FS.Exists (Target) then
               FS.Create_Directory (Target);
            elsif FS.Kind (Target) /= FS.Directory then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.not_directory", "not a directory");
               return;
            end if;
            Apply_Source_Metadata;

            declare
               Iteration_Ok : Boolean;

               procedure Copy_Child (Name : String; Full_Name : String; Stop : in out Boolean) is
                  Child_Ok : Boolean;
               begin
                  pragma Unreferenced (Stop);
                  Copy_Path
                    (Context,
                     Full_Name,
                     Posix_Tools.Commands.File_Helpers.Join_Path (Target, Name),
                     Recursive,
                     Preserve_Mode,
                     Preserve_Links,
                     Child_Ok);
                  Ok := Ok and Child_Ok;
               end Copy_Child;

               procedure For_Each_Child is new FS.For_Each_Directory_Entry (Copy_Child);
            begin
               For_Each_Child (Source, Iteration_Ok);
               if not Iteration_Ok then
                  Ok := False;
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context,
                     Source,
                     "posix_tools.diagnostic.file.read_directory_failed",
                     "cannot read directory");
               end if;
            end;
            return;
         exception
            when others =>
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
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
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.not_directory", "not a directory");
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
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
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
            elsif Info.Available
              and then Info.Kind in FS.FIFO | FS.Character_Device | FS.Block_Device | FS.Socket
            then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            else
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Source, "posix_tools.diagnostic.file.unsupported_type", "unsupported file type");
            end if;
         end;
         return;
      end if;

      if FS.Exists (Target) and then FS.Same_File (Source, Target) then
         Ok := False;
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Target, "posix_tools.diagnostic.file.same_file", "source and destination are the same file");
         return;
      end if;

      declare
         Copy_Status : FS.Copy_File_Status;
      begin
         FS.Copy_Regular_File (Source, Target, Copy_Status);
         Ok := Copy_Status = FS.Copy_Ok;
         case Copy_Status is
            when FS.Copy_Ok =>
               Apply_Source_Metadata;

            when FS.Source_Open_Failed | FS.Source_Read_Failed =>
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Source, "posix_tools.diagnostic.file.read_failed", "cannot read file");

            when FS.Target_Open_Failed | FS.Target_Write_Failed =>
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Target, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end case;
      end;
   end Copy_Path;
end Posix_Tools.Commands.File_Helpers.Copying;
