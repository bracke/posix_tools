with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.File_Operations.Removing is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.File_Kind;

   --  Whether the directory Path could be read and holds no entries.
   function Is_Empty_Directory (Path : String) return Boolean;

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

   procedure Remove_Path
     (Path    : String;
      Options : Remove_Options;
      Watcher : in out Observer'Class;
      Outcome : out Operation_Outcome)
   is
      procedure Fail (Error : Operation_Error);

      --  Remove the directory Path, once asked about, and say why it would
      --  not go when it does not.
      procedure Delete_Directory;

      --  Remove the file or link Path, once asked about.
      procedure Delete_Entry;

      --  Remove each entry of the directory Path, and then the directory.
      procedure Delete_Tree;

      procedure Delete_Directory is
      begin
         if not Watcher.Confirm_Removal (Path, Remove_Directory) then
            Outcome := Skipped;
            return;
         end if;

         begin
            FS.Delete_Directory (Path);
         exception
            when others =>
               Fail (if Is_Empty_Directory (Path) then Cannot_Remove else Directory_Not_Empty);
               return;
         end;

         Watcher.Finished (Path);
      end Delete_Directory;

      procedure Delete_Entry is
         Removed : Boolean := True;
      begin
         if not Watcher.Confirm_Removal (Path, Remove_Entry) then
            Outcome := Skipped;
            return;
         end if;

         begin
            if FS.Is_Link (Path) then
               Removed := FS.Delete_Link (Path);
            else
               FS.Delete_File (Path);
            end if;
         exception
            when others =>
               Removed := False;
         end;

         if Removed then
            Watcher.Finished (Path);
         else
            Fail (Cannot_Remove);
         end if;
      end Delete_Entry;

      procedure Delete_Tree is
         Listed : Boolean;
         --  Whether an entry was left as asked: the directory then stays.
         Kept   : Boolean := False;

         procedure Remove_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean);

         procedure Remove_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean) is
            pragma Unreferenced (Kind);
            Child : Operation_Outcome;
         begin
            Remove_Path (FS.Child_Path (Path, Name), Options, Watcher, Child);
            Kept := Kept or else Child = Skipped;
            Outcome := Combined (Outcome, Child);
            Stop := Watcher.Cancelled;
         end Remove_Child;

         procedure Each is new FS.For_Each_Listed_Entry (Remove_Child);
      begin
         if not Is_Empty_Directory (Path) and then not Watcher.Confirm_Removal (Path, Descend_Into) then
            Outcome := Skipped;
            return;
         end if;

         Each (Path, Listed);

         if not Listed then
            Fail (Cannot_Read_Directory);
         elsif Watcher.Cancelled then
            Outcome := Combined (Outcome, Cancelled);
         elsif Outcome /= Done then
            null;
         elsif Kept then
            Outcome := Skipped;
         else
            Delete_Directory;
         end if;
      end Delete_Tree;

      procedure Fail (Error : Operation_Error) is
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

      if FS.Is_Link (Path) then
         --  The link itself, never what it points to.
         Delete_Entry;
      elsif not FS.Exists (Path) then
         Fail (No_Such_File);
      elsif FS.Kind (Path) /= FS.Directory then
         Delete_Entry;
      elsif Options.Recursive then
         Delete_Tree;
      elsif Options.Empty_Directories then
         Delete_Directory;
      else
         Fail (Is_A_Directory);
      end if;
   end Remove_Path;
end Posix_Tools.File_Operations.Removing;
