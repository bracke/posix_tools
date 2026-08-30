with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers.File_Modes;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Mkdir is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Mode_Helpers renames Posix_Tools.Commands.Text_Helpers.File_Modes;

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
         Available : Boolean := False;
         Base      : Natural := 0;
         Selected  : Mode_Helpers.Selected_Mode;
      begin
         if Mode_Helpers.Is_Symbolic (Mode_Selection) then
            Base := FS.File_Permission_Bits (Path, Available) mod 8#1000#;
            if not Available then
               Base := 0;
            end if;
         end if;
         Selected := Mode_Helpers.Selected (Mode_Selection, Base, 8#1000#);
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
                                 Posix_Tools.Commands.Helpers.Usage_Error
                                   (Context, Result, "invalid mode '" & Arg & "'");
                                 return;
                              end if;
                           end;
                           Position := Arg'Last + 1;
                        else
                           if First = Context.Argument_Count then
                              Posix_Tools.Commands.Helpers.Usage_Error
                                (Context, Result, "missing option argument '-m'");
                              return;
                           end if;
                           declare
                              Accepted : Boolean;
                           begin
                              Record_Mode (Context.Argument (First + 1), Accepted);
                              if not Accepted then
                                 Posix_Tools.Commands.Helpers.Usage_Error
                                   (Context, Result, "invalid mode '" & Context.Argument (First + 1) & "'");
                                 return;
                              end if;
                           end;
                           First := First + 1;
                           Position := Arg'Last + 1;
                        end if;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "unknown option '-" & Arg (Position) & "'");
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
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;
      for I in First .. Context.Argument_Count loop
         begin
            if Parents then
               FS.Create_Path (Context.Argument (I));
            else
               FS.Create_Directory (Context.Argument (I));
            end if;
            if Has_Mode then
               declare
                  Mode_Ok      : Boolean;
                  Desired_Mode : constant Natural := Selected_Mode_For (Context.Argument (I), Mode_Ok);
               begin
                  if not Mode_Ok or else not FS.Set_Permissions (Context.Argument (I), Desired_Mode) then
                     Ok := False;
                     Posix_Tools.Commands.Helpers.Subject_Operational_Error
                       (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
                  end if;
               end;
            end if;
         exception
            when others =>
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Context.Argument (I), "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end;
      end loop;
      Result.Status :=
        (if Ok then Posix_Tools.Exit_Status.Success else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Mkdir;
