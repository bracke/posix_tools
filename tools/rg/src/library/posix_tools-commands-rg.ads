with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;
with Posix_Tools.Exit_Status;

--  rg: recursively search paths for text matching a pattern list.
package Posix_Tools.Commands.Rg is
   --  No match was found.
   No_Matches : constant Posix_Tools.Exit_Status.Code := 1;
   --  A usage, input, matching, or output error occurred.
   Trouble    : constant Posix_Tools.Exit_Status.Code := 2;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result);
end Posix_Tools.Commands.Rg;
