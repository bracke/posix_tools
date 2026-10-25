with Posix_Tools.Commands.Contexts;
with Posix_Tools.File_Operations;

--  How a command hears from a shared filesystem operation: each error is
--  written on the command's context as a diagnostic under the operation's
--  catalog key, naming the path the error is about, and each question the
--  command's -i asks is put on its standard error and answered from its
--  standard input.
package Posix_Tools.Commands.Operation_Reports is
   type Prompt_Kind is
     (No_Prompt,
      --  Ask before each existing target that is not a directory is
      --  replaced, inside a tree as well, as cp -i does.
      Copy_Overwrite,
      --  Ask before each entry is removed and before going into a directory
      --  that holds entries, as rm -i does.
      Removal);

   type Context_Observer (Context : not null access Posix_Tools.Commands.Contexts.Context'Class) is
     new Posix_Tools.File_Operations.Observer with record
      Prompt : Prompt_Kind := No_Prompt;
   end record;

   overriding procedure Report_Error
     (Self  : in out Context_Observer;
      Path  : String;
      Error : Posix_Tools.File_Operations.Operation_Error);

   overriding function Resolve_Conflict
     (Self   : in out Context_Observer;
      Source : String;
      Target : String) return Posix_Tools.File_Operations.Conflict_Choice;

   overriding function Confirm_Removal
     (Self     : in out Context_Observer;
      Path     : String;
      Question : Posix_Tools.File_Operations.Removal_Question) return Boolean;

   --  Put the prompt Key gives, with Path where it names it, and read the
   --  answer: True for an affirmative one.
   function Ask
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Key     : String;
      Default : String;
      Path    : String) return Boolean;
end Posix_Tools.Commands.Operation_Reports;
