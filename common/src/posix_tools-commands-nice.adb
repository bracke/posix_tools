with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Nice_Fields;

package body Posix_Tools.Commands.Nice is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First      : Positive := 1;
      Adjustment : Integer := 10;
      Exit_Code  : Integer := 0;
      Arguments  : Posix_Tools.Arguments.Vector;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count = 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      if Context.Argument (First) = "-n" then
         if First = Context.Argument_Count then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-n'");
            return;
         else
            declare
               Parsed : constant Posix_Tools.Text.Nice_Fields.Parsed_Adjustment :=
                 Posix_Tools.Text.Nice_Fields.Parse_Adjustment (Context.Argument (First + 1));
            begin
               if not Parsed.Valid then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid operand '" & Context.Argument (First + 1) & "'");
                  return;
               end if;
               Adjustment := Parsed.Value;
            end;
         end if;
         First := First + 2;
      elsif Context.Argument (First)'Length > 2
        and then Context.Argument (First) (1 .. 2) = "-n"
      then
         declare
            Parsed : constant Posix_Tools.Text.Nice_Fields.Parsed_Adjustment :=
              Posix_Tools.Text.Nice_Fields.Parse_Adjustment
                (Context.Argument (First) (3 .. Context.Argument (First)'Last));
         begin
            if not Parsed.Valid then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (First) & "'");
               return;
            end if;
            Adjustment := Parsed.Value;
         end;
         First := First + 1;
      end if;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in First + 1 .. Context.Argument_Count loop
         Arguments.Append (Context.Argument (I));
      end loop;

      if not Context.Execute_Utility_With_Nice_Adjustment
        (Context.Argument (First), Arguments, Adjustment, Exit_Code)
      then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Context.Argument (First), "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end if;

      if Exit_Code < 0 or else Exit_Code > 255 then
         Result.Status := Posix_Tools.Exit_Status.Internal_Failure;
      else
         Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
      end if;
   end Run;
end Posix_Tools.Commands.Nice;
