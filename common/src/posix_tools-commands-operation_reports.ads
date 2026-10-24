with Posix_Tools.Commands.Contexts;
with Posix_Tools.File_Operations;

--  How a command hears from a shared filesystem operation: each error is
--  written on the command's context as the diagnostic it has always given,
--  under the operation's catalog key, naming the path the error is about.
package Posix_Tools.Commands.Operation_Reports is
   type Context_Observer (Context : not null access Posix_Tools.Commands.Contexts.Context'Class) is
     new Posix_Tools.File_Operations.Observer with record
      --  Note errors in Failed without writing them, for a command that
      --  writes one diagnostic of its own for the operand instead.
      Quiet  : Boolean := False;
      Failed : Boolean := False;
   end record;

   overriding procedure Report_Error
     (Self  : in out Context_Observer;
      Path  : String;
      Error : Posix_Tools.File_Operations.Operation_Error);
end Posix_Tools.Commands.Operation_Reports;
