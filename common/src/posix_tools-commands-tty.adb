with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Tty is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Silent : Boolean := False;
      First  : Positive;
      Valid  : Boolean;

      --  -s, the one option.
      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
         pragma Unreferenced (Name, Value, Result);
      begin
         Silent := True;
         Valid := True;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "s", "", First, Valid);
      if not Valid then
         return;
      elsif Context.Argument_Count >= First then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Extra_Operand, Context.Argument (First));
         return;
      end if;

      if Context.Standard_Input_Is_Terminal then
         if not Silent then
            Context.Put_Line (Context.Standard_Input_Terminal_Name);
         end if;
         Posix_Tools.Commands.Helpers.Finish (Context, Result);
      else
         if not Silent then
            Context.Put_Line ("not a tty");
         end if;
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;

      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run;
end Posix_Tools.Commands.Tty;
