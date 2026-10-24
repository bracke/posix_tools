--  Filesystem operations shared by the commands and by explore.
--
--  Each operation is Context-free: it takes what it works on as parameters and
--  tells an Observer what happens, leaving diagnostics, prompts, and output to
--  the caller, so a command-line tool and an interactive one can both build on
--  it. A command's observer writes each error as the command always has; an
--  interactive one can also show progress, stop the operation, and decide
--  what to do about a target that already exists.
package Posix_Tools.File_Operations is
   type Operation_Error is
     (Cannot_Read,
      Cannot_Open,
      Cannot_Remove,
      Is_A_Directory,
      Not_A_Directory,
      Same_File,
      Cannot_Read_Directory,
      Unsupported_Type);

   --  The message catalog key that describes Error, and the text to show
   --  where the catalog has none.
   function Message_Key (Error : Operation_Error) return String;
   function Default_Message (Error : Operation_Error) return String;

   type Conflict_Choice is
     (Overwrite,  --  Replace the existing target.
      Skip);      --  Leave it, and this source, alone.

   type Observer is abstract tagged limited null record;

   --  Something could not be done to Path. The operation carries on with
   --  what else it can and ends without success.
   procedure Report_Error (Self : in out Observer; Path : String; Error : Operation_Error) is abstract;

   --  Whether the operation should stop now. Asked between entries and
   --  between the blocks of a file being copied; once it answers True the
   --  operation ends without success and without reporting an error. The
   --  default never stops.
   function Cancelled (Self : in out Observer) return Boolean;

   --  Copied bytes of the file at Path have been written so far.
   procedure Progress (Self : in out Observer; Path : String; Copied : Long_Long_Integer) is null;

   --  Path, a file, link, or directory, has been dealt with.
   procedure Finished (Self : in out Observer; Path : String) is null;

   --  Target already exists and Source would replace it. The default
   --  replaces it, as the commands do once any prompt of theirs has been
   --  answered.
   function Resolve_Conflict (Self : in out Observer; Source, Target : String) return Conflict_Choice;
end Posix_Tools.File_Operations;
