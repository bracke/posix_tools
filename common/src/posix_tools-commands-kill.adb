with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Signals;
with Posix_Tools.Text.Signal_Names;

package body Posix_Tools.Commands.Kill is
   package Signals renames Posix_Tools.Host_Adapters.Signals;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First  : Positive := 1;
      Chosen : Signals.Signal := Signals.Terminate_Signal;
      Ok     : Boolean := True;

      function Signal_From_Name (Text : String; Item : out Signals.Signal) return Boolean is
      begin
         if Text = "" then
            Item := Signals.Terminate_Signal;
            return False;
         end if;
         declare
            Known  : constant Posix_Tools.Text.Signal_Names.Signal_Name :=
              Posix_Tools.Text.Signal_Names.Known_Signal_Name (Text);
            Number_Text_First : constant Positive :=
              (if Posix_Tools.Text.Signal_Names.Is_SIG_Prefixed (Text) then Text'First + 3 else Text'First);
            Number : Natural := 0;
         begin
            if Posix_Tools.Commands.Text_Helpers.Parse_Natural_Text
              (Text (Number_Text_First .. Text'Last), Number)
            then
               return Signals.From_Number (Integer (Number), Item);
            end if;

            case Known is
               when Posix_Tools.Text.Signal_Names.Hangup_Name =>
                  Item := Signals.Hangup;
               when Posix_Tools.Text.Signal_Names.Interrupt_Name =>
                  Item := Signals.Interrupt;
               when Posix_Tools.Text.Signal_Names.Quit_Name =>
                  Item := Signals.Quit;
               when Posix_Tools.Text.Signal_Names.Kill_Name =>
                  Item := Signals.Kill;
               when Posix_Tools.Text.Signal_Names.Terminate_Name =>
                  Item := Signals.Terminate_Signal;
               when Posix_Tools.Text.Signal_Names.Stop_Name =>
                  Item := Signals.Stop;
               when Posix_Tools.Text.Signal_Names.Terminal_Stop_Name =>
                  Item := Signals.Terminal_Stop;
               when Posix_Tools.Text.Signal_Names.Continue_Name =>
                  Item := Signals.Continue;
               when Posix_Tools.Text.Signal_Names.Pipe_Name =>
                  Item := Signals.Pipe;
               when Posix_Tools.Text.Signal_Names.Unknown_Signal_Name =>
                  Item := Signals.Terminate_Signal;
                  return False;
            end case;
            return Signals.Is_Supported (Item);
         end;
      end Signal_From_Name;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count = 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      if Context.Argument (1) = "-l" then
         for Item in Signals.Signal loop
            if Signals.Is_Supported (Item) then
               Context.Put_Line (Signals.Name (Item));
            end if;
         end loop;
         Result.Status :=
           (if Context.Output_Failed
            then Posix_Tools.Exit_Status.Operational_Failure
            else Posix_Tools.Exit_Status.Success);
         return;
      elsif Context.Argument_Count >= 2 and then Context.Argument (1) = "-s" then
         if not Signal_From_Name (Context.Argument (2), Chosen) then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid operand '" & Context.Argument (2) & "'");
            return;
         end if;
         First := 3;
      elsif Context.Argument (1)'Length > 1 and then Context.Argument (1) (1) = '-' then
         if not Signal_From_Name (Context.Argument (1) (2 .. Context.Argument (1)'Last), Chosen) then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid operand '" & Context.Argument (1) & "'");
            return;
         end if;
         First := 2;
      end if;

      if Context.Argument_Count < First then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         declare
            Pid : Natural;
         begin
            if not Posix_Tools.Commands.Text_Helpers.Parse_Natural_Text
                (Context.Argument (I), Pid)
              or else not Signals.Send_To_Process (Integer (Pid), Chosen)
            then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
            end if;
         end;
      end loop;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Kill;
