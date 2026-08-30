with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Unlink is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First : Positive := 1;
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
      elsif Context.Argument_Count > First then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Context.Argument (First + 1) & "'");
         return;
      end if;

      begin
         FS.Delete_File (Context.Argument (First));
         Result.Status :=
           (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
            else Posix_Tools.Exit_Status.Success);
      exception
         when others =>
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Context.Argument (First), "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end;
   end Run;
end Posix_Tools.Commands.Unlink;
