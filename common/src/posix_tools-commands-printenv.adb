with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;

package body Posix_Tools.Commands.Printenv is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First   : Positive := 1;
      Missing : Boolean := False;
      Output  : Posix_Tools.Commands.Helpers.Output_Buffer;
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
               Posix_Tools.Commands.Helpers.Buffered_Put_Line
                 (Output, Context, Pair);
            end loop;
         end;
      else
         for I in First .. Context.Argument_Count loop
            declare
               Name : constant String := Context.Argument (I);
            begin
               if not Context.Environment_Defined (Name) then
                  Missing := True;
               else
                  Posix_Tools.Commands.Helpers.Buffered_Put_Line
                    (Output, Context, Context.Environment_Value (Name));
               end if;
            end;
         end loop;
      end if;

      Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
      Posix_Tools.Commands.Helpers.Finish (Context, Result, not Missing);
   end Run;
end Posix_Tools.Commands.Printenv;
