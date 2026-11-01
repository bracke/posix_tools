with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Realpath is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First : Positive := 1;
      Ok    : Boolean := True;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count > 0 and then Context.Argument (1) = "--" then
         First := 2;
      end if;

      if Context.Argument_Count < First then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         begin
            declare
               --  Real_Path is "" when the operand does not resolve.
               Resolved : constant String := FS.Real_Path (Context.Argument (I));
            begin
               if Resolved = "" then
                  Ok := False;
                  Posix_Tools.Commands.Helpers.Subject_Operational_Error
                    (Context, Context.Argument (I), "posix_tools.diagnostic.file.resolve_failed",
                     "cannot resolve path");
               else
                  Context.Put_Line (Resolved);
               end if;
            end;
         exception
            when others =>
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Context.Argument (I), "posix_tools.diagnostic.file.resolve_failed", "cannot resolve path");
         end;
      end loop;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;
end Posix_Tools.Commands.Realpath;
