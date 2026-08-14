with Posix_Tools.Commands.Expanded;

package body Posix_Tools.Commands.Fold is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result) is
   begin
      Posix_Tools.Commands.Expanded.Run (Posix_Tools.Commands.Expanded.Fold_Command, Context, Result);
   end Run;
end Posix_Tools.Commands.Fold;
