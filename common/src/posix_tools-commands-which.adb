with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Executables;

package body Posix_Tools.Commands.Which is
   package Exec renames Posix_Tools.Host_Adapters.Executables;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First       : Positive := 1;
      Missing_Any : Boolean := False;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count > 0 and then Context.Argument (1) = "--" then
         First := 2;
      end if;

      if Context.Argument_Count < First then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         declare
            Located : constant String := Exec.Locate (Context.Argument (I));
         begin
            if Located = "" then
               Missing_Any := True;
            else
               Context.Put_Line (Located);
            end if;
         end;
      end loop;

      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      elsif Missing_Any then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      else
         Result.Status := Posix_Tools.Exit_Status.Success;
      end if;
   end Run;
end Posix_Tools.Commands.Which;
