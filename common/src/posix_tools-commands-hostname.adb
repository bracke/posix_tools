with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Hostname is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count = 0 then
         declare
            Name : constant String := Context.Current_Node_Name;
         begin
            if Name = "" then
               Posix_Tools.Commands.Helpers.Operational_Error
                 (Context, "posix_tools.diagnostic.unsupported", "unsupported platform capability");
               Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            else
               Context.Put_Line (Name);
               Result.Status :=
                 (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
                  else Posix_Tools.Exit_Status.Success);
            end if;
         end;
      elsif Context.Argument_Count = 1 then
         if Context.Set_Node_Name (Context.Argument (1)) then
            Result.Status :=
              (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
               else Posix_Tools.Exit_Status.Success);
         else
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.unsupported", "unsupported platform capability");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         end if;
      else
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Context.Argument (2) & "'");
      end if;
   end Run;
end Posix_Tools.Commands.Hostname;
