with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Cat is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Ok      : Boolean;
      All_Ok  : Boolean := True;
      Count   : constant Natural := Context.Argument_Count;
      First   : constant Positive :=
        (if Count > 0 and then Context.Argument (1) = "--" then 2 else 1);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Count < First then
         Posix_Tools.Commands.File_Helpers.Copy_File (Context, "-", Ok);
         All_Ok := Ok;
      else
         for I in First .. Count loop
            Posix_Tools.Commands.File_Helpers.Copy_File (Context, Context.Argument (I), Ok);
            All_Ok := All_Ok and Ok;
         end loop;
      end if;

      Result.Status :=
        (if All_Ok then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Cat;
