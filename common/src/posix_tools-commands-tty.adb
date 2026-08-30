with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Tty is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Silent : Boolean := False;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count > 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Context.Argument (2) & "'");
         return;
      elsif Context.Argument_Count = 1 then
         if Context.Argument (1) = "-s" then
            Silent := True;
         else
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '" & Context.Argument (1) & "'");
            return;
         end if;
      end if;

      if Context.Standard_Input_Is_Terminal then
         if not Silent then
            Context.Put_Line (Context.Standard_Input_Terminal_Name);
         end if;
         Result.Status :=
           (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
            else Posix_Tools.Exit_Status.Success);
      else
         if not Silent then
            Context.Put_Line ("not a tty");
         end if;
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;

      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run;
end Posix_Tools.Commands.Tty;
