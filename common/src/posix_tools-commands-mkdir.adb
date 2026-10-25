with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Text_Helpers.File_Modes;
with Posix_Tools.Exit_Status;
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
      First            : Positive := 1;
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
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First)'Length > 1
           and then Context.Argument (First) (Context.Argument (First)'First) = '-'
         then
            declare
               Arg      : constant String := Context.Argument (First);
               Position : Positive := Arg'First + 1;
            begin
               while Position <= Arg'Last loop
                  case Arg (Position) is
                     when 'p' =>
                        Parents := True;
                        Position := Position + 1;
                     when 'm' =>
                        if Position < Arg'Last then
                           declare
                              Accepted : Boolean;
                           begin
                              Record_Mode (Arg (Position + 1 .. Arg'Last), Accepted);
                              if not Accepted then
                                 Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Mode, Arg);
                                 return;
                              end if;
                           end;
                           Position := Arg'Last + 1;
                        else
                           if First = Context.Argument_Count then
                              Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Option_Argument, "-m");
                              return;
                           end if;
                           declare
                              Accepted : Boolean;
                           begin
                              Record_Mode (Context.Argument (First + 1), Accepted);
                              if not Accepted then
                                 Posix_Tools.Commands.Helpers.Usage_Error
                                   (Context, Result, Invalid_Mode, Context.Argument (First + 1));
                                 return;
                              end if;
                           end;
                           First := First + 1;
                           Position := Arg'Last + 1;
                        end if;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, Unknown_Option, "-" & Arg (Position));
                        return;
                  end case;
               end loop;
            end;
            First := First + 1;
         else
            exit;
         end if;
      end loop;
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
            else
               begin
                  if Parents then
                     FS.Create_Path (Path);
                  else
                     FS.Create_Directory (Path);
                  end if;

                  if Has_Mode then
                     declare
                        Mode_Ok      : Boolean;
                        Desired_Mode : constant Natural := Selected_Mode_For (Path, Mode_Ok);
                     begin
                        if not Mode_Ok or else not FS.Set_Permissions (Path, Desired_Mode) then
                           Fail ("posix_tools.diagnostic.file.mode_failed", "cannot change permissions");
                        end if;
                     end;
                  end if;
               exception
                  when others =>
                     Fail ("posix_tools.diagnostic.file.create_failed", "cannot create directory");
               end;
            end if;
         end;
      end loop;
      Result.Status :=
        (if Ok then Posix_Tools.Exit_Status.Success else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Mkdir;
