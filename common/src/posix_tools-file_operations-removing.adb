with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.File_Operations.Removing is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.File_Kind;

   procedure Remove_Path
     (Path    : String;
      Options : Remove_Options;
      Watcher : in out Observer'Class;
      Outcome : out Operation_Outcome)
   is
      procedure Fail (Error : Operation_Error);

      --  Run Action, and fail with Cannot_Remove if it raises.
      generic
         with procedure Action (Path : String);
      procedure Attempt;

      procedure Attempt is
      begin
         Action (Path);
         Watcher.Finished (Path);
      exception
         when others =>
            Fail (Cannot_Remove);
      end Attempt;

      procedure Fail (Error : Operation_Error) is
      begin
         Outcome := Failed;
         Watcher.Report_Error (Path, Error);
      end Fail;

      procedure Delete_Directory is new Attempt (FS.Delete_Directory);
      procedure Delete_File is new Attempt (FS.Delete_File);
   begin
      Outcome := Done;

      if Watcher.Cancelled then
         Outcome := Cancelled;
         return;
      end if;

      if FS.Is_Link (Path) then
         if FS.Delete_Link (Path) then
            Watcher.Finished (Path);
         else
            Fail (Cannot_Remove);
         end if;

         return;
      end if;

      if FS.Kind (Path) /= FS.Directory then
         Delete_File;
      elsif Options.Recursive then
         declare
            Listed : Boolean;

            procedure Remove_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean);

            procedure Remove_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean) is
               pragma Unreferenced (Kind);
               Child : Operation_Outcome;
            begin
               Remove_Path (FS.Child_Path (Path, Name), Options, Watcher, Child);
               Outcome := Combined (Outcome, Child);
               Stop := Watcher.Cancelled;
            end Remove_Child;

            procedure Each is new FS.For_Each_Listed_Entry (Remove_Child);
         begin
            Each (Path, Listed);

            if not Listed then
               Fail (Cannot_Read_Directory);
            elsif Watcher.Cancelled then
               Outcome := Combined (Outcome, Cancelled);
            elsif Outcome = Done then
               Delete_Directory;
            end if;
         end;
      elsif Options.Empty_Directories then
         Delete_Directory;
      else
         Fail (Is_A_Directory);
      end if;
   end Remove_Path;
end Posix_Tools.File_Operations.Removing;
