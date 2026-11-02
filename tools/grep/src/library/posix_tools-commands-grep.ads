with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;
with Posix_Tools.Exit_Status;

--  grep: search files for lines that match a pattern list, through greplib.
package Posix_Tools.Commands.Grep is
   --  No line was selected.
   No_Lines_Selected : constant Posix_Tools.Exit_Status.Code := 1;
   --  An error occurred: a usage error, an input that could not be read,
   --  or output that could not be written.
   Trouble           : constant Posix_Tools.Exit_Status.Code := 2;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result);
end Posix_Tools.Commands.Grep;
