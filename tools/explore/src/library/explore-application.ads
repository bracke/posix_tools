with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;

--  The life of one explore session: checking the operands and the terminal,
--  taking the screen over, running until the user quits, and handing the
--  terminal back as it was found -- on every way out, including an exception
--  and a terminate or hangup signal.
package Explore.Application is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result);
end Explore.Application;
