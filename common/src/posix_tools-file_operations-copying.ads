--  Copying a file, a link, a special file, or a directory tree.
package Posix_Tools.File_Operations.Copying is
   type Copy_Options is record
      --  Copy directories and what they contain; without it a directory is
      --  reported as one and not copied.
      Recursive      : Boolean := False;
      --  Give each copy its source's permission bits, owner, and times.
      Preserve_Mode  : Boolean := False;
      --  Copy a symbolic link as a link instead of what it points to.
      Preserve_Links : Boolean := False;
   end record;

   --  Copy Source to Target, which names the copy itself, not a directory to
   --  put it in. A directory is merged into an existing one at Target. Ok is
   --  False when anything could not be copied or the copy was cancelled.
   procedure Copy_Path
     (Source   : String;
      Target   : String;
      Options  : Copy_Options;
      Watcher  : in out Observer'Class;
      Ok       : out Boolean);

   --  Whether Child is Parent or lies inside it, comparing full paths.
   function Is_Same_Or_Descendant (Parent, Child : String) return Boolean;
end Posix_Tools.File_Operations.Copying;
