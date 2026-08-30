with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Yes is
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Line : Unbounded_String :=
        (if Context.Argument_Count = 0 then To_Unbounded_String ("y") else Null_Unbounded_String);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         if I > 1 then
            Append (Line, " ");
         end if;
         Append (Line, Context.Argument (I));
      end loop;

      while not Context.Output_Failed loop
         Context.Put_Line (To_String (Line));
      end loop;

      Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
   end Run;
end Posix_Tools.Commands.Yes;
