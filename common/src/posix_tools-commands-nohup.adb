with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Signals;

package body Posix_Tools.Commands.Nohup is
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First         : Positive := 1;
      Exit_Code     : Integer := 0;
      Arguments     : Posix_Tools.Arguments.Vector;
      Previous      : Posix_Tools.Host_Adapters.Signals.Disposition :=
        Posix_Tools.Host_Adapters.Signals.Default_Disposition;
      Have_Previous : Boolean := False;
      Ignored       : Boolean := False;
      Redirect_Out  : constant Boolean := Context.Standard_Output_Is_Terminal;
      Redirect_Err  : constant Boolean := Context.Standard_Error_Is_Terminal;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count > 0 and then Context.Argument (1) = "--" then
         First := 2;
      end if;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in First + 1 .. Context.Argument_Count loop
         Arguments.Append (Context.Argument (I));
      end loop;

      if Posix_Tools.Host_Adapters.Signals.Is_Supported (Posix_Tools.Host_Adapters.Signals.Hangup) then
         Have_Previous :=
           Posix_Tools.Host_Adapters.Signals.Current_Disposition
             (Posix_Tools.Host_Adapters.Signals.Hangup, Previous);
         Ignored :=
           Posix_Tools.Host_Adapters.Signals.Set_Disposition
             (Posix_Tools.Host_Adapters.Signals.Hangup,
              Posix_Tools.Host_Adapters.Signals.Ignore_Disposition);
      end if;

      if not Context.Execute_Utility_With_Redirected_Output
        (Context.Argument (First), Arguments, "nohup.out", Redirect_Out, Redirect_Err, Exit_Code)
      then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Context.Argument (First), "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end if;

      if Ignored and then Have_Previous then
         if not Posix_Tools.Host_Adapters.Signals.Set_Disposition
           (Posix_Tools.Host_Adapters.Signals.Hangup, Previous)
         then
            null;
         end if;
      end if;

      if Exit_Code < 0 or else Exit_Code > 255 then
         Result.Status := Posix_Tools.Exit_Status.Internal_Failure;
      else
         Result.Status := Posix_Tools.Exit_Status.Code (Exit_Code);
      end if;
   end Run;
end Posix_Tools.Commands.Nohup;
