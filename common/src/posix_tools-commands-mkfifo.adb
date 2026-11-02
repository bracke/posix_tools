with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Octal_Modes;

package body Posix_Tools.Commands.Mkfifo is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First : Positive;
      Valid : Boolean;
      Mode  : Natural := 8#666#;
      Ok    : Boolean := True;

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
      begin
         Valid := True;
         declare
            Parsed_Mode : constant Posix_Tools.Text.Octal_Modes.Parsed_Mode :=
              Posix_Tools.Text.Octal_Modes.Parse_Mode (Value);
         begin
            if Parsed_Mode.Valid then
               Mode := Parsed_Mode.Value;
            else
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
               Valid := False;
            end if;
         end;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "m", "m", First, Valid);
      if not Valid then
         return;
      end if;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         if not FS.Create_FIFO (Context.Argument (I), Mode) then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Ok := False;
         end if;
      end loop;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;
end Posix_Tools.Commands.Mkfifo;
