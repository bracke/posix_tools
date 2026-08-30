with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Printenv is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First   : Positive := 1;
      Missing : Boolean := False;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count > 0 and then Context.Argument (1) = "--" then
         First := 2;
      end if;

      if Context.Argument_Count < First then
         declare
            Env : constant Posix_Tools.Arguments.Vector := Context.Environment_Pairs;
         begin
            for Pair of Env loop
               Context.Put_Line (Pair);
            end loop;
         end;
      else
         for I in First .. Context.Argument_Count loop
            declare
               Name  : constant String := Context.Argument (I);
               Value : constant String := Context.Environment_Value (Name);
            begin
               if not Context.Environment_Defined (Name) then
                  Missing := True;
               else
                  Context.Put_Line (Value);
               end if;
            end;
         end loop;
      end if;

      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      elsif Missing then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      else
         Result.Status := Posix_Tools.Exit_Status.Success;
      end if;
   end Run;
end Posix_Tools.Commands.Printenv;
