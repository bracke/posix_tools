with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Whoami is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count > 0 then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Context.Argument (1) & "'");
         return;
      end if;

      declare
         Name : constant String := Posix_Tools.Commands.Helpers.Current_User_Name (Context);
      begin
         if Name /= "" then
            Context.Put_Line (Name);
            Result.Status :=
              (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
               else Posix_Tools.Exit_Status.Success);
         else
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.unsupported", "unsupported platform capability");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         end if;
      end;
   end Run;
end Posix_Tools.Commands.Whoami;
