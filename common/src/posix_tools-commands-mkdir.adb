with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Text_Helpers.File_Modes;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Paths;

package body Posix_Tools.Commands.Mkdir is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Mode_Helpers renames Posix_Tools.Commands.Text_Helpers.File_Modes;

   use type FS.File_Kind;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Parents          : Boolean := False;
      Ok               : Boolean := True;
      First            : Positive;
      Parsed_Ok        : Boolean;
      Has_Mode         : Boolean := False;
      Mode_Selection   : Mode_Helpers.Mode_Selection;

      procedure Record_Mode (Mode : String; Accepted : out Boolean);
      function Selected_Mode_For (Path : String; Valid : out Boolean) return Natural;

      procedure Record_Mode (Mode : String; Accepted : out Boolean) is
      begin
         Mode_Helpers.Parse (Mode, Mode_Selection, Accepted);
         if Accepted then
            Has_Mode := True;
         end if;
      end Record_Mode;

      function Selected_Mode_For (Path : String; Valid : out Boolean) return Natural is
         pragma Unreferenced (Path);
         --  POSIX: a symbolic mode's + and - are taken from a=rwx, not from
         --  what the file mode creation mask left the new directory.
         Selected : constant Mode_Helpers.Selected_Mode :=
           Mode_Helpers.Selected (Mode_Selection, 8#777#, 8#10000#, Is_Directory => True);
      begin
         Valid := Selected.Valid;
         return Selected.Mode;
      end Selected_Mode_For;

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
      begin
         Valid := True;
         if Name = 'p' then
            Parents := True;
         else
            Record_Mode (Value, Valid);
            if not Valid then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Mode, Value);
            end if;
         end if;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "mp", "m", First, Parsed_Ok);
      if not Parsed_Ok then
         return;
      end if;
      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;
      for I in First .. Context.Argument_Count loop
         declare
            Path : constant String := Context.Argument (I);

            procedure Fail (Key, Default : String);

            procedure Fail (Key, Default : String) is
            begin
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error (Context, Path, Key, Default);
            end Fail;
         begin
            if not Parents and then (FS.Exists (Path) or else FS.Is_Link (Path)) then
               Fail ("posix_tools.diagnostic.file.exists", "file exists");
            elsif Parents and then FS.Exists (Path) and then FS.Kind (Path) /= FS.Directory then
               Fail ("posix_tools.diagnostic.file.not_directory", "not a directory");
            elsif not Parents and then not FS.Exists (Posix_Tools.Paths.Dirname (Path)) then
               Fail ("posix_tools.diagnostic.file.missing", "no such file or directory");
            elsif not (if Parents then FS.Create_Path (Path) else FS.Create_Directory (Path)) then
               Fail ("posix_tools.diagnostic.file.create_failed", "cannot create directory");
            elsif Has_Mode then
               declare
                  Mode_Ok      : Boolean;
                  Desired_Mode : constant Natural := Selected_Mode_For (Path, Mode_Ok);
               begin
                  if not Mode_Ok or else not FS.Set_Permissions (Path, Desired_Mode) then
                     Fail ("posix_tools.diagnostic.file.mode_failed", "cannot change permissions");
                  end if;
               end;
            end if;
         end;
      end loop;
      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;
end Posix_Tools.Commands.Mkdir;
