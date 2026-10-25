--  Copying a file, a link, a special file, or a directory tree.
package Posix_Tools.File_Operations.Copying is
   type Copy_Options is record
      --  Copy directories and what they contain; without it a directory is
      --  reported as one and not copied, and a special file is read for
      --  what it holds, as a regular one is, rather than made again.
      Recursive      : Boolean := False;
      --  Give each copy its source's permission bits, the set-user-ID,
      --  set-group-ID, and sticky bits among them, its owner, and its times.
      --  Where the owner cannot be kept, as for anyone but the superuser,
      --  the copy keeps neither set-ID bit, and that is no failure.
      Preserve_Mode  : Boolean := False;
      --  Copy a symbolic link as a link instead of what it points to.
      Preserve_Links : Boolean := False;
   end record;

   --  What a command's options ask of a copy beyond Copy_Options.
   type Copy_Behaviour is record
      --  Follow Source itself when it is a symbolic link, while the links
      --  inside a tree it leads to are copied as links: cp -H.
      Follow_Source_Link : Boolean := False;
      --  Where an existing target cannot be opened for writing, remove it
      --  and try once more: cp -f.
      Remove_Unwritable  : Boolean := False;
   end record;

   --  Copy Source to Target, which names the copy itself, not a directory to
   --  put it in. A directory is merged into an existing one at Target, and is
   --  Done when all it holds was copied or skipped. A directory that would
   --  be copied into itself, or that, links being followed, leads back to a
   --  directory being copied around it, is reported and left out.
   procedure Copy_Path
     (Source    : String;
      Target    : String;
      Options   : Copy_Options;
      Watcher   : in out Observer'Class;
      Outcome   : out Operation_Outcome;
      Behaviour : Copy_Behaviour := (others => <>));

   --  Whether Child is Parent or lies inside it, once symbolic links in
   --  either have been resolved; Child need not exist yet.
   function Is_Same_Or_Descendant (Parent, Child : String) return Boolean;
end Posix_Tools.File_Operations.Copying;
