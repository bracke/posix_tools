with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Rmdir is
   use Ada.Strings.Unbounded;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Ok      : Boolean := True;
      Parents : Boolean := False;
      First   : Positive := 1;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count
        and then Context.Argument (First)'Length > 1
        and then Context.Argument (First) (1) = '-'
      loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         end if;

         for Ch of Context.Argument (First) (2 .. Context.Argument (First)'Last) loop
            case Ch is
               when 'p' =>
                  Parents := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         begin
            if Parents then
               declare
                  Current : Unbounded_String := To_Unbounded_String (Context.Argument (I));
               begin
                  loop
                     begin
                        FS.Delete_Directory (To_String (Current));
                     exception
                        when others =>
                           Ok := False;
                           Posix_Tools.Commands.Helpers.Subject_Operational_Error
                             (Context,
                              To_String (Current),
                              "posix_tools.diagnostic.file.open_failed",
                              "cannot open file");
                           exit;
                     end;

                     declare
                        Parent : constant String := FS.Containing_Directory (To_String (Current));
                     begin
                        exit when Parent = "" or else Parent = "." or else Parent = To_String (Current);
                        Current := To_Unbounded_String (Parent);
                     end;
                  end loop;
               end;
            else
               FS.Delete_Directory (Context.Argument (I));
            end if;
         exception
            when others =>
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end;
      end loop;

      Result.Status :=
        (if Ok then Posix_Tools.Exit_Status.Success else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Rmdir;
