--  Moving a file, a link, or a directory tree.
package Posix_Tools.File_Operations.Moving is
   --  Move Source to Target, which names the moved entry itself. A rename
   --  where the host can; where it cannot, as across filesystems, a copy that
   --  keeps modes, owners, times, and symbolic links as links, and then
   --  removal of the source, which is removed only once all of it has been
   --  copied.
   procedure Move_Path
     (Source  : String;
      Target  : String;
      Watcher : in out Observer'Class;
      Outcome : out Operation_Outcome);

   --  What Move_Path does where the host cannot rename: replace Target as
   --  rename(2) would, and then copy Source there and remove it. A target
   --  that is not a directory is removed first, so that the copy is a new
   --  file, not one written through a link or into another name of the old
   --  one; a directory target must be empty, as rename(2) has it, and the
   --  source a directory too. On its own so that it can be tried on one
   --  file system; Target's conflict is taken as settled.
   procedure Move_By_Copying
     (Source  : String;
      Target  : String;
      Watcher : in out Observer'Class;
      Outcome : out Operation_Outcome);
end Posix_Tools.File_Operations.Moving;
