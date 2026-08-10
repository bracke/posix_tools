with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Paths;

package body Posix_Tools.Commands.Basename is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Count : constant Natural := Context.Argument_Count;
      First : constant Positive :=
        (if Count > 0 and then Context.Argument (1) = "--" then 2 else 1);
      Operand_Count : constant Natural := (if Count < First then 0 else Count - First + 1);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Operand_Count = 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
      elsif Operand_Count > 2 then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Context.Argument (First + 2) & "'");
      else
         Context.Put
           (Posix_Tools.Paths.Basename
              (Context.Argument (First),
               (if Operand_Count = 2 then Context.Argument (First + 1) else ""))
            & Character'Val (10));
         Result.Status :=
           (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
            else Posix_Tools.Exit_Status.Success);
      end if;
   end Run;
end Posix_Tools.Commands.Basename;
