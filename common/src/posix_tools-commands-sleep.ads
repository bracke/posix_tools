with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;

package Posix_Tools.Commands.Sleep is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result);
end Posix_Tools.Commands.Sleep;
