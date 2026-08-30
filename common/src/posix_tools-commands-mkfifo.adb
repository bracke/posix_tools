with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Octal_Modes;

package body Posix_Tools.Commands.Mkfifo is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First : Positive := 1;
      Mode  : Natural := 8#666#;
      Ok    : Boolean := True;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) = "-m" then
            declare
               Parsed_Mode : Posix_Tools.Text.Octal_Modes.Parsed_Mode;
            begin
               if First = Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-m'");
                  return;
               end if;

               Parsed_Mode := Posix_Tools.Text.Octal_Modes.Parse_Mode (Context.Argument (First + 1));
               if not Parsed_Mode.Valid then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
                  return;
               end if;

               Mode := Parsed_Mode.Value;
               First := First + 2;
            end;
         elsif Context.Argument (First)'Length > 1 and then Context.Argument (First) (1) = '-' then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "unknown option '" & Context.Argument (First) & "'");
            return;
         else
            exit;
         end if;
      end loop;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         if not FS.Create_FIFO (Context.Argument (I), Mode) then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Ok := False;
         end if;
      end loop;

      Result.Status :=
        (if Context.Output_Failed or else not Ok then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Mkfifo;
