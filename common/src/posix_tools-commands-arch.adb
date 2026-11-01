with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;

package body Posix_Tools.Commands.Arch is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count > 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Extra_Operand, Context.Argument (1));
         return;
      end if;

      Context.Put_Line (Context.Current_Machine_Name);
      Posix_Tools.Commands.Helpers.Finish (Context, Result);
   end Run;
end Posix_Tools.Commands.Arch;
