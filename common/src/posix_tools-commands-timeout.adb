with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Duration_Fields;

package body Posix_Tools.Commands.Timeout is
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First           : Positive := 1;
      Preserve_Status : Boolean := False;
      Timeout_Ms      : Natural := 0;
      Kill_After_Ms   : Natural := 0;
      Signal_Name     : Unbounded_String := To_Unbounded_String ("TERM");
      Timed_Out       : Boolean := False;
      Exit_Code       : Integer := 0;
      Arguments       : Posix_Tools.Arguments.Vector;

      procedure Require_Operand (Option : String);

      procedure Require_Operand (Option : String) is
      begin
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "missing option argument '" & Option & "'");
      end Require_Operand;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First);
         begin
            if Arg = "--" then
               First := First + 1;
               exit;
            elsif Arg = "--preserve-status" then
               Preserve_Status := True;
               First := First + 1;
            elsif Arg = "--foreground" then
               First := First + 1;
            elsif Arg = "-s" or else Arg = "--signal" then
               if First = Context.Argument_Count then
                  Require_Operand (Arg);
                  return;
               end if;
               Signal_Name := To_Unbounded_String (Context.Argument (First + 1));
               First := First + 2;
            elsif Arg'Length > 10 and then Arg (Arg'First .. Arg'First + 9) = "--signal=" then
               Signal_Name := To_Unbounded_String (Arg (Arg'First + 10 .. Arg'Last));
               First := First + 1;
            elsif Arg = "-k" or else Arg = "--kill-after" then
               if First = Context.Argument_Count then
                  Require_Operand (Arg);
                  return;
               end if;
               declare
                  Parsed : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Milliseconds :=
                    Posix_Tools.Text.Duration_Fields.Parse_Milliseconds (Context.Argument (First + 1));
               begin
                  if not Parsed.Valid then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "invalid duration '" & Context.Argument (First + 1) & "'");
                     return;
                  end if;
                  Kill_After_Ms := Parsed.Value;
               end;
               First := First + 2;
            elsif Arg'Length > 13 and then Arg (Arg'First .. Arg'First + 12) = "--kill-after=" then
               declare
                  Parsed : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Milliseconds :=
                    Posix_Tools.Text.Duration_Fields.Parse_Milliseconds
                      (Arg (Arg'First + 13 .. Arg'Last));
               begin
                  if not Parsed.Valid then
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "invalid duration '" & Arg (Arg'First + 13 .. Arg'Last) & "'");
                     return;
                  end if;
                  Kill_After_Ms := Parsed.Value;
               end;
               First := First + 1;
            elsif Arg'Length > 0 and then Arg (Arg'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '" & Arg & "'");
               return;
            else
               exit;
            end if;
         end;
      end loop;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      elsif First = Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      declare
         Parsed : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Milliseconds :=
           Posix_Tools.Text.Duration_Fields.Parse_Milliseconds (Context.Argument (First));
      begin
         if not Parsed.Valid then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid duration '" & Context.Argument (First) & "'");
            return;
         end if;
         Timeout_Ms := Parsed.Value;
      end;

      if To_String (Signal_Name) = "" then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand ''");
         return;
      end if;

      for I in First + 2 .. Context.Argument_Count loop
         Arguments.Append (Context.Argument (I));
      end loop;

      if not Context.Execute_Utility_With_Timeout
        (Context.Argument (First + 1), Arguments, Timeout_Ms + Kill_After_Ms, Exit_Code, Timed_Out)
      then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Context.Argument (First + 1), "posix_tools.diagnostic.file.open_failed", "cannot open file");
         if Exit_Code in 126 .. 127 then
            Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
         else
            Result.Status := Posix_Tools.Exit_Status.Utility_Cannot_Invoke;
         end if;
      elsif Timed_Out and then not Preserve_Status then
         Result.Status := Posix_Tools.Exit_Status.Code (124);
      elsif Exit_Code in Integer (Posix_Tools.Exit_Status.Code'First)
        .. Integer (Posix_Tools.Exit_Status.Code'Last)
      then
         Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
      else
         Result.Status := Posix_Tools.Exit_Status.Internal_Failure;
      end if;

      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run;
end Posix_Tools.Commands.Timeout;
