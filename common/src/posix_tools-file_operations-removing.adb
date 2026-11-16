with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.File_Operations.Removing is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.Entry_Kind;

   procedure Remove_Known_Path
     (Path    : String;
      Listed_As : FS.Listed_Kind;
      Options : Remove_Options;
      Watcher : in out Observer'Class;
      Outcome : out Operation_Outcome);

   procedure Remove_Known_Path
     (Path      : String;
      Listed_As : FS.Listed_Kind;
      Options   : Remove_Options;
      Watcher   : in out Observer'Class;
      Outcome   : out Operation_Outcome)
   is
      procedure Fail (Error : Operation_Error);

      --  Remove the directory Path, once asked about, and say why it would
      --  not go when it does not.
      procedure Delete_Directory;

      --  Remove the file or link Path, once asked about.
      procedure Delete_Entry (Is_Link : Boolean);

      --  Remove each entry of the directory Path, and then the directory.
      procedure Delete_Tree;

      procedure Delete_Directory is
      begin
         if not Watcher.Confirm_Removal (Path, Remove_Directory) then
            Outcome := Skipped;
            return;
         end if;

         if not FS.Delete_Directory (Path) then
            Fail (if Is_Empty_Directory (Path) then Cannot_Remove else Directory_Not_Empty);
            return;
         end if;

         Watcher.Finished (Path);
      end Delete_Directory;

      procedure Delete_Entry (Is_Link : Boolean) is
      begin
         if not Watcher.Confirm_Removal (Path, Remove_Entry) then
            Outcome := Skipped;
            return;
         end if;

         if (if Is_Link then FS.Delete_Link (Path) else FS.Delete_File (Path)) then
            Watcher.Finished (Path);
         else
            Fail (Cannot_Remove);
         end if;
      end Delete_Entry;

      procedure Delete_Tree is
         Listed : Boolean;
         --  Whether an entry was left as asked: the directory then stays.
         Kept   : Boolean := False;
         Descend_Confirmed : Boolean := False;
         Descend_Declined  : Boolean := False;

         procedure Remove_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean);

         procedure Remove_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean) is
            Child : Operation_Outcome;
         begin
            --  Reaching a first entry proves the directory is nonempty, so
            --  confirmation and traversal share one enumeration.
            if not Descend_Confirmed then
               if not Watcher.Confirm_Removal (Path, Descend_Into) then
                  Descend_Declined := True;
                  Stop := True;
                  return;
               end if;
               Descend_Confirmed := True;
            end if;

            Remove_Known_Path
              (FS.Child_Path (Path, Name), Kind,
               Options, Watcher, Child);
            Kept := Kept or else Child = Skipped;
            Outcome := Combined (Outcome, Child);
            Stop := Watcher.Cancelled;
         end Remove_Child;

         procedure Each is new FS.For_Each_Listed_Entry (Remove_Child);
      begin
         Each (Path, Listed);

         if not Listed then
            Fail (Cannot_Read_Directory);
         elsif Descend_Declined then
            Outcome := Skipped;
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

      declare
         Kind : constant FS.Entry_Kind :=
           (case Listed_As is
              when FS.Listed_Regular   => FS.Entry_Regular,
              when FS.Listed_Directory => FS.Entry_Directory,
              when FS.Listed_Link      => FS.Entry_Link,
              when FS.Listed_Other     => FS.Entry_Special,
              when FS.Listed_Unknown   => FS.Entry_Kind_Of (Path));
      begin
         case Kind is
            when FS.Entry_Missing =>
               Fail (No_Such_File);
            when FS.Entry_Error =>
               Fail (Cannot_Read);
            when FS.Entry_Link | FS.Entry_Regular | FS.Entry_Special =>
               --  A link itself, never what it points to.
               Delete_Entry (Kind = FS.Entry_Link);
            when FS.Entry_Directory =>
               if Options.Recursive then
                  Delete_Tree;
               elsif Options.Empty_Directories then
                  Delete_Directory;
               else
                  Fail (Is_A_Directory);
               end if;
         end case;
      end;
   end Remove_Known_Path;

   procedure Remove_Path
     (Path    : String;
      Options : Remove_Options;
      Watcher : in out Observer'Class;
      Outcome : out Operation_Outcome)
   is
   begin
      Remove_Known_Path
        (Path, FS.Listed_Unknown, Options, Watcher, Outcome);
   end Remove_Path;
end Posix_Tools.File_Operations.Removing;
