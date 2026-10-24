--  Moving a file, a link, or a directory tree.
package Posix_Tools.File_Operations.Moving is
   --  Move Source to Target, which names the moved entry itself. A rename
   --  where the host can; where it cannot, as across filesystems, a copy that
   --  keeps modes, owners, times, and symbolic links as links, and then
   --  removal of the source. Ok is False when the move did not complete or
   --  was cancelled; the source is removed only once all of it has been
   --  copied.
   procedure Move_Path
     (Source  : String;
      Target  : String;
      Watcher : in out Observer'Class;
      Ok      : out Boolean);
end Posix_Tools.File_Operations.Moving;
