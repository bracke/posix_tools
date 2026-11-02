with Ada.Calendar;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Touch_Time_Parsing;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Clock;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Touch is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   --  What touch's options ask for.
   type Settings is record
      --  The time touch runs at, read once: what -d and -t are relative to.
      Now              : Ada.Calendar.Time;
      Create_Missing   : Boolean := True;
      Touch_Access     : Boolean := True;
      Touch_Modify     : Boolean := True;
      --  -a or -m was given: the first of them clears the other time.
      Have_Selector    : Boolean := False;
      --  The time -d, -r or -t gave.
      Have_Target_Time : Boolean := False;
      Target_Time      : FS.File_Time := FS.Current_File_Time;
   end record;

   --  Give Path the times Options ask for, making it unless -c.
   procedure Apply_Touch
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Options : Settings;
      Path    : String;
      Ok      : in out Boolean);

   procedure Fail_Open
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String;
      Ok      : in out Boolean);

   --  Read touch's options into Options; First is the first operand. Valid
   --  is False, with the diagnostic and status given, when one is wrong.
   procedure Parse_Options
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Options : in out Settings;
      First   : out Positive;
      Valid   : out Boolean);

   --  Take Operand as the time -d, -r or -t (Option) gives. Valid is False,
   --  with the diagnostic and status given, when it gives none.
   procedure Select_Time
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Options : in out Settings;
      Option  : Character;
      Operand : String;
      Valid   : out Boolean);

   procedure Apply_Touch
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Options : Settings;
      Path    : String;
      Ok      : in out Boolean)
   is
      Written : Boolean;

      procedure Apply_Selected_Time (Time : FS.File_Time);

      procedure Apply_Selected_Time (Time : FS.File_Time) is
         Access_Time       : FS.File_Time := Time;
         Modification_Time : FS.File_Time := Time;
      begin
         if (not Options.Touch_Access and then not FS.File_Access_Time_From_File (Path, Access_Time))
           or else (not Options.Touch_Modify and then not FS.File_Time_From_File (Path, Modification_Time))
           or else not FS.Set_File_Times (Path, Access_Time, Modification_Time)
         then
            Fail_Open (Context, Path, Ok);
         end if;
      end Apply_Selected_Time;
   begin
      if FS.Exists (Path) then
         if Options.Have_Target_Time then
            Apply_Selected_Time (Options.Target_Time);
         elsif not Options.Touch_Access or else not Options.Touch_Modify then
            Apply_Selected_Time (FS.Current_File_Time);
         elsif FS.Kind (Path) = FS.Ordinary_File then
            declare
               File_Ok : Boolean;
               Data    : constant String :=
                 Posix_Tools.Commands.File_Helpers.Streaming.Read_File (Context, Path, File_Ok);
            begin
               if File_Ok then
                  FS.Write_File (Path, Data, False, Written);
                  Ok := Ok and Written;
               else
                  Ok := False;
               end if;
            end;
         else
            Apply_Selected_Time (FS.Current_File_Time);
         end if;
      elsif Options.Create_Missing then
         FS.Write_File (Path, "", False, Written);
         Ok := Ok and Written;
         if Written then
            if Options.Have_Target_Time then
               Apply_Selected_Time (Options.Target_Time);
            elsif not Options.Touch_Access or else not Options.Touch_Modify then
               Apply_Selected_Time (FS.Current_File_Time);
            end if;
         end if;
      end if;
   end Apply_Touch;

   procedure Fail_Open
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Path    : String;
      Ok      : in out Boolean) is
   begin
      Ok := False;
      Posix_Tools.Commands.Helpers.Subject_Operational_Error
        (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
   end Fail_Open;

   procedure Parse_Options
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Options : in out Settings;
      First   : out Positive;
      Valid   : out Boolean) is
   begin
      First := 1;
      Valid := True;

      while First <= Context.Argument_Count loop
         declare
            Argument : constant String := Context.Argument (First);
         begin
            if Argument = "--" then
               First := First + 1;
               exit;
            elsif Argument'Length <= 1 or else Argument (Argument'First) /= '-' then
               exit;
            end if;

            for Position in Argument'First + 1 .. Argument'Last loop
               case Argument (Position) is
                  when 'a' =>
                     if not Options.Have_Selector then
                        Options.Touch_Modify := False;
                        Options.Have_Selector := True;
                     end if;
                     Options.Touch_Access := True;
                  when 'm' =>
                     if not Options.Have_Selector then
                        Options.Touch_Access := False;
                        Options.Have_Selector := True;
                     end if;
                     Options.Touch_Modify := True;
                  when 'c' =>
                     Options.Create_Missing := False;
                  when 'd' | 'r' | 't' =>
                     --  The time is the rest of the argument, or the next one.
                     if Position < Argument'Last then
                        Select_Time
                          (Context, Result, Options, Argument (Position), Argument (Position + 1 .. Argument'Last),
                           Valid);
                     elsif First = Context.Argument_Count then
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, Missing_Option_Argument, "-" & Argument (Position));
                        Valid := False;
                     else
                        First := First + 1;
                        Select_Time (Context, Result, Options, Argument (Position), Context.Argument (First), Valid);
                     end if;

                     if not Valid then
                        return;
                     end if;
                     exit;
                  when others =>
                     Posix_Tools.Commands.Helpers.Usage_Error
                       (Context, Result, Unknown_Option, "-" & Argument (Position));
                     Valid := False;
                     return;
               end case;
            end loop;
         end;
         First := First + 1;
      end loop;
   end Parse_Options;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Options : Settings := (Now => Posix_Tools.Host_Adapters.Clock.Now, others => <>);
      First   : Positive;
      Valid   : Boolean;
      Ok      : Boolean := True;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse_Options (Context, Result, Options, First, Valid);
      if not Valid then
         return;
      elsif First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         begin
            Apply_Touch (Context, Options, Context.Argument (I), Ok);
         exception
            when others =>
               Fail_Open (Context, Context.Argument (I), Ok);
         end;
      end loop;
      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;

   procedure Select_Time
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Options : in out Settings;
      Option  : Character;
      Operand : String;
      Valid   : out Boolean)
   is
      Unused : Boolean := True;
   begin
      if Option = 'r' then
         --  A reference file that cannot be read is an operational failure.
         Valid := FS.Exists (Operand) and then FS.File_Time_From_File (Operand, Options.Target_Time);
         if not Valid then
            Fail_Open (Context, Operand, Unused);
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         end if;
      else
         Valid :=
           (if Option = 't'
            then Posix_Tools.Commands.Touch_Time_Parsing.Parse_Explicit_Time
              (Operand, Options.Now, Options.Target_Time)
            else Posix_Tools.Commands.Touch_Time_Parsing.Parse_Date_Time
              (Operand, Options.Now, Options.Target_Time));
         if not Valid then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Timestamp, Operand);
         end if;
      end if;

      Options.Have_Target_Time := Options.Have_Target_Time or else Valid;
   end Select_Time;
end Posix_Tools.Commands.Touch;
