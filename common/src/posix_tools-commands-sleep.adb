with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Duration_Fields;

package body Posix_Tools.Commands.Sleep is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Max_Duration_Seconds : constant Long_Long_Float := 86_400.0;
      Total_Seconds        : Long_Long_Float := 0.0;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count = 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         declare
            Parsed : constant Posix_Tools.Text.Duration_Fields.Parsed_Duration_Seconds :=
              Posix_Tools.Text.Duration_Fields.Parse_Seconds
                (Context.Argument (I), Max_Duration_Seconds);
         begin
            if not Parsed.Valid then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (I) & "'");
               return;
            end if;
            if Total_Seconds > Max_Duration_Seconds - Parsed.Value then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (I) & "'");
               return;
            end if;
            Total_Seconds := Total_Seconds + Parsed.Value;
         end;
      end loop;

      delay Duration (Total_Seconds);
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Sleep;
