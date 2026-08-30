with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Chgrp is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First     : Positive := 1;
      Recursive : Boolean := False;
      Group     : Natural := 0;
      Ok        : Boolean := True;

      procedure Apply_One (Path : String);

      procedure Apply_Children is new Posix_Tools.Commands.Helpers.For_Each_Directory_Child
        (Action => Apply_One);

      procedure Apply_One (Path : String) is
         User      : Natural;
         Old_Group : Natural;
         Available : Boolean;
      begin
         if Recursive then
            declare
               Listed : Boolean;
            begin
               Apply_Children (Path, Listed);
               Ok := Ok and Listed;
            end;
         end if;
         FS.File_Ownership (Path, User, Old_Group, Available);
         if not Available then
            User := 0;
         end if;
         if not FS.Set_Ownership (Path, User, Group) then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end if;
      exception
         when others =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end Apply_One;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) = "-R" then
            Recursive := True;
            First := First + 1;
         else
            exit;
         end if;
      end loop;

      if Context.Argument_Count < First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      elsif not Posix_Tools.Commands.Helpers.Resolve_Group_Id (Context.Argument (First), Group) then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "invalid operand '" & Context.Argument (First) & "'");
         return;
      end if;

      for I in First + 1 .. Context.Argument_Count loop
         Apply_One (Context.Argument (I));
      end loop;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Chgrp;
