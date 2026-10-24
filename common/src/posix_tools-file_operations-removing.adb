with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.File_Operations.Removing is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.File_Kind;

   function Join_Path (Directory, Leaf : String) return String is
     (if Directory = "" or else Directory (Directory'Last) = '/' then Directory & Leaf else Directory & "/" & Leaf);

   procedure Remove_Path
     (Path    : String;
      Options : Remove_Options;
      Watcher : in out Observer'Class;
      Ok      : out Boolean)
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
         Ok := False;
         Watcher.Report_Error (Path, Error);
      end Fail;

      procedure Delete_Directory is new Attempt (FS.Delete_Directory);
      procedure Delete_File is new Attempt (FS.Delete_File);
   begin
      Ok := True;

      if Watcher.Cancelled then
         Ok := False;
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
               Child_Ok : Boolean;
            begin
               Remove_Path (Join_Path (Path, Name), Options, Watcher, Child_Ok);
               Ok := Ok and Child_Ok;
               Stop := Watcher.Cancelled;
            end Remove_Child;

            procedure Each is new FS.For_Each_Listed_Entry (Remove_Child);
         begin
            Each (Path, Listed);

            if not Listed then
               Fail (Cannot_Read_Directory);
            elsif Watcher.Cancelled then
               Ok := False;
            elsif Ok then
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
