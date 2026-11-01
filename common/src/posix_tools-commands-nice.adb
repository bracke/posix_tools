with Posix_Tools.Arguments;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Nice_Fields;

package body Posix_Tools.Commands.Nice is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First      : Positive;
      Valid      : Boolean;
      Adjustment : Integer := 10;
      Exit_Code  : Integer := 0;
      Arguments  : Posix_Tools.Arguments.Vector;

      --  -n, with its increment Value.
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
         pragma Unreferenced (Name);
         Parsed : constant Posix_Tools.Text.Nice_Fields.Parsed_Adjustment :=
           Posix_Tools.Text.Nice_Fields.Parse_Adjustment (Value);
      begin
         Valid := Parsed.Valid;
         if Valid then
            Adjustment := Parsed.Value;
         else
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
         end if;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "n", "n", First, Valid);
      if not Valid then
         return;
      end if;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
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
