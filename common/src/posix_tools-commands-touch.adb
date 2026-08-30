with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Touch_Times;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Touch is
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Ok : Boolean := True;
      Written : Boolean;
      Create_Missing : Boolean := True;
      Target_Time : FS.File_Time := FS.Current_File_Time;
      Have_Target_Time : Boolean := False;
      Touch_Access : Boolean := True;
      Touch_Modify : Boolean := True;
      Have_Time_Selector : Boolean := False;
      First : Positive := 1;

      procedure Select_Reference_Time (Reference : String; Selected : out Boolean) is
      begin
         Selected := False;
         if not FS.Exists (Reference) then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Reference, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Ok := False;
         else
            if FS.File_Time_From_File (Reference, Target_Time) then
               Have_Target_Time := True;
               Selected := True;
            else
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Reference, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               Ok := False;
            end if;
         end if;
      exception
         when others =>
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Reference, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Ok := False;
      end Select_Reference_Time;

      procedure Select_Explicit_Time (Timestamp : String; Selected : out Boolean) is
      begin
         if Posix_Tools.Commands.Touch_Times.Parse_Explicit_Time (Timestamp, Target_Time) then
            Have_Target_Time := True;
            Selected := True;
         else
            Selected := False;
         end if;
      end Select_Explicit_Time;

      procedure Select_Date_Time (Timestamp : String; Selected : out Boolean) is
      begin
         if Posix_Tools.Commands.Touch_Times.Parse_Date_Time (Timestamp, Target_Time) then
            Have_Target_Time := True;
            Selected := True;
         else
            Selected := False;
         end if;
      end Select_Date_Time;

      procedure Apply_Touch (Path : String) is
         procedure Apply_Selected_Time (Time : FS.File_Time) is
            Access_Time       : FS.File_Time := Time;
            Modification_Time : FS.File_Time := Time;
         begin
            if not Touch_Access and then not FS.File_Access_Time_From_File (Path, Access_Time) then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               return;
            end if;

            if not Touch_Modify and then not FS.File_Time_From_File (Path, Modification_Time) then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               return;
            end if;

            if not FS.Set_File_Times (Path, Access_Time, Modification_Time) then
               Ok := False;
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            end if;
         end Apply_Selected_Time;
      begin
         if FS.Exists (Path) then
            if Have_Target_Time then
               Apply_Selected_Time (Target_Time);
            elsif not Touch_Access or else not Touch_Modify then
               Apply_Selected_Time (FS.Current_File_Time);
            elsif FS.Kind (Path) = FS.Ordinary_File then
               declare
                  File_Ok : Boolean;
                  Data : constant String :=
                    Posix_Tools.Commands.File_Helpers.Read_File (Context, Path, File_Ok);
               begin
                  if File_Ok then
                     Posix_Tools.Commands.File_Helpers.Write_File (Path, Data, False, Written);
                     Ok := Ok and Written;
                  else
                     Ok := False;
                  end if;
               end;
            else
               Apply_Selected_Time (FS.Current_File_Time);
            end if;
         elsif Create_Missing then
            Posix_Tools.Commands.File_Helpers.Write_File (Path, "", False, Written);
            Ok := Ok and Written;
            if Written then
               if Have_Target_Time then
                  Apply_Selected_Time (Target_Time);
               elsif not Touch_Access or else not Touch_Modify then
                  Apply_Selected_Time (FS.Current_File_Time);
               end if;
            end if;
         end if;
      end Apply_Touch;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) = "-t" then
            if First = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-t'");
               return;
            end if;
            declare
               Selected : Boolean;
            begin
               Select_Explicit_Time (Context.Argument (First + 1), Selected);
               if not Selected then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid timestamp '" & Context.Argument (First + 1) & "'");
                  return;
               end if;
            end;
            First := First + 2;
         elsif Context.Argument (First) = "-d" then
            if First = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-d'");
               return;
            end if;
            declare
               Selected : Boolean;
            begin
               Select_Date_Time (Context.Argument (First + 1), Selected);
               if not Selected then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "invalid timestamp '" & Context.Argument (First + 1) & "'");
                  return;
               end if;
            end;
            First := First + 2;
         elsif Context.Argument (First) = "-r" then
            if First = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-r'");
               return;
            end if;
            declare
               Selected : Boolean;
            begin
               Select_Reference_Time (Context.Argument (First + 1), Selected);
               if not Selected then
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
            end;
            First := First + 2;
         elsif Context.Argument (First)'Length > 1 and then Context.Argument (First) (1) = '-' then
            for Ch of Context.Argument (First) (2 .. Context.Argument (First)'Last) loop
               case Ch is
                  when 'a' =>
                     if not Have_Time_Selector then
                        Touch_Modify := False;
                        Have_Time_Selector := True;
                     end if;
                     Touch_Access := True;
                  when 'm' =>
                     if not Have_Time_Selector then
                        Touch_Access := False;
                        Have_Time_Selector := True;
                     end if;
                     Touch_Modify := True;
                  when 'c' =>
                     Create_Missing := False;
                  when 'd' =>
                     if Context.Argument (First)'Length > 2 then
                        declare
                           Timestamp : constant String :=
                             Context.Argument (First)
                               (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last);
                           Selected : Boolean;
                        begin
                           Select_Date_Time (Timestamp, Selected);
                           if not Selected then
                              Posix_Tools.Commands.Helpers.Usage_Error
                                (Context, Result, "invalid timestamp '" & Timestamp & "'");
                              return;
                           end if;
                        end;
                        exit;
                     elsif First = Context.Argument_Count then
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-d'");
                        return;
                     else
                        declare
                           Selected : Boolean;
                        begin
                           Select_Date_Time (Context.Argument (First + 1), Selected);
                           if not Selected then
                              Posix_Tools.Commands.Helpers.Usage_Error
                                (Context, Result, "invalid timestamp '" & Context.Argument (First + 1) & "'");
                              return;
                           end if;
                        end;
                        First := First + 1;
                        exit;
                     end if;
                  when 'r' =>
                     if Context.Argument (First)'Length > 2 then
                        declare
                           Reference : constant String :=
                             Context.Argument (First)
                               (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last);
                           Selected : Boolean;
                        begin
                           Select_Reference_Time (Reference, Selected);
                           if not Selected then
                              Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                              return;
                           end if;
                        end;
                        exit;
                     elsif First = Context.Argument_Count then
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-r'");
                        return;
                     else
                        declare
                           Selected : Boolean;
                        begin
                           Select_Reference_Time (Context.Argument (First + 1), Selected);
                           if not Selected then
                              Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                              return;
                           end if;
                        end;
                        First := First + 1;
                        exit;
                     end if;
                  when 't' =>
                     if Context.Argument (First)'Length > 2 then
                        declare
                           Timestamp : constant String :=
                             Context.Argument (First)
                               (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last);
                           Selected : Boolean;
                        begin
                           Select_Explicit_Time (Timestamp, Selected);
                           if not Selected then
                              Posix_Tools.Commands.Helpers.Usage_Error
                                (Context, Result, "invalid timestamp '" & Timestamp & "'");
                              return;
                           end if;
                        end;
                        exit;
                     elsif First = Context.Argument_Count then
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-t'");
                        return;
                     else
                        declare
                           Selected : Boolean;
                        begin
                           Select_Explicit_Time (Context.Argument (First + 1), Selected);
                           if not Selected then
                              Posix_Tools.Commands.Helpers.Usage_Error
                                (Context, Result, "invalid timestamp '" & Context.Argument (First + 1) & "'");
                              return;
                           end if;
                        end;
                        First := First + 1;
                        exit;
                     end if;
                  when others =>
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, "unknown option '-" & Ch & "'");
                     return;
               end case;
            end loop;
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
            Apply_Touch (Context.Argument (I));
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

end Posix_Tools.Commands.Touch;
