--  Removing a file, a link, or a directory tree.
package Posix_Tools.File_Operations.Removing is
   type Remove_Options is record
      --  Remove directories and everything in them.
      Recursive         : Boolean := False;
      --  Remove a directory that is empty, as rm -d does.
      Empty_Directories : Boolean := False;
   end record;

   --  Remove Path. A symbolic link is removed itself, never what it points
   --  to, and a tree is walked without following links, so that nothing
   --  outside it is touched. When anything could not be removed, or the
   --  removal was cancelled, what could be removed is gone.
   procedure Remove_Path
     (Path    : String;
      Options : Remove_Options;
      Watcher : in out Observer'Class;
      Outcome : out Operation_Outcome);
end Posix_Tools.File_Operations.Removing;
