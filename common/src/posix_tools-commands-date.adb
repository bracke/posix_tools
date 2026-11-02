with Ada.Calendar;
with Ada.Calendar.Time_Zones;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Date_Parsing;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Clock;
with Posix_Tools.Text.Date_Formats;

package body Posix_Tools.Commands.Date is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      --  POSIX's default output format.
      Default_Format : constant String := "%a %b %e %H:%M:%S %Z %Y";

      Now : constant Ada.Calendar.Time := Posix_Tools.Host_Adapters.Clock.Now;
      Time_Zone_Offset : Ada.Calendar.Time_Zones.Time_Offset;
      Time_Zone_Name : Unbounded_String;
      Has_Format : Boolean := False;
      Format_Arg : Unbounded_String;
      Has_Set_Time : Boolean := False;
      Set_Text : Unbounded_String;
      Set_Time : Ada.Calendar.Time := Now;
      TZ_Text : constant String := Context.Environment_Value ("TZ");
      Force_UTC : Boolean := False;
      End_Options : Boolean := False;

      --  The zone's offset and name at Time: UTC with -u, else TZ's zone,
      --  else the host's local zone.
      procedure Zone_At (Time : Ada.Calendar.Time);

      procedure Zone_At (Time : Ada.Calendar.Time) is
         Parsed_Offset : Ada.Calendar.Time_Zones.Time_Offset;
         Parsed_Name : Unbounded_String;
      begin
         if Force_UTC then
            Time_Zone_Offset := 0;
            Time_Zone_Name := To_Unbounded_String ("UTC");
            return;
         end if;
         Time_Zone_Offset := Posix_Tools.Host_Adapters.Clock.Local_Offset (Time);
         Time_Zone_Name := Null_Unbounded_String;
         if TZ_Text /= ""
           and then Posix_Tools.Commands.Date_Parsing.Resolve_Time_Zone
             (TZ_Text, Time, Context.Category_Locale (Posix_Tools.Commands.Contexts.Time),
              Parsed_Offset, Parsed_Name)
         then
            Time_Zone_Offset := Parsed_Offset;
            Time_Zone_Name := Parsed_Name;
         end if;
      end Zone_At;

      function Parse_Set_Time (Offset : Ada.Calendar.Time_Zones.Time_Offset) return Boolean is
        (Posix_Tools.Commands.Date_Parsing.Parse_Set_Date_Time
           (To_String (Set_Text), Ada.Calendar.Year (Now), Offset, Set_Time));

   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         if not End_Options and then Context.Argument (I) = "--" then
            End_Options := True;
         elsif not End_Options and then Context.Argument (I) = "-u" then
            Force_UTC := True;
         elsif Context.Argument (I)'Length > 0
           and then Context.Argument (I) (Context.Argument (I)'First) = '+'
           and then not Has_Format
           and then not Has_Set_Time
         then
            Format_Arg := To_Unbounded_String
              (Context.Argument (I) (Context.Argument (I)'First + 1 .. Context.Argument (I)'Last));
            Has_Format := True;
         elsif not Has_Format and then not Has_Set_Time then
            Set_Text := To_Unbounded_String (Context.Argument (I));
            Has_Set_Time := True;
         else
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Extra_Operand, Context.Argument (I));
            return;
         end if;
      end loop;

      Zone_At (Now);
      if Has_Set_Time then
         --  The time to set is in the zone's offset at that time, which
         --  may differ from now's across a daylight saving change.
         if not Parse_Set_Time (Time_Zone_Offset) then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, To_String (Set_Text));
            return;
         end if;
         declare
            use type Ada.Calendar.Time_Zones.Time_Offset;
            First_Offset : constant Ada.Calendar.Time_Zones.Time_Offset := Time_Zone_Offset;
         begin
            Zone_At (Set_Time);
            if Time_Zone_Offset /= First_Offset and then Parse_Set_Time (Time_Zone_Offset) then
               Zone_At (Set_Time);
            end if;
         end;
      end if;

      if Has_Set_Time and then not Context.Set_System_Date_Time (Set_Time) then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.date.set_failed", "cannot set system date");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      Context.Put_Line
        (Posix_Tools.Text.Date_Formats.Format_Date
           ((if Has_Format then To_String (Format_Arg) else Default_Format),
            Set_Time,
            Time_Zone_Offset,
            To_String (Time_Zone_Name),
            Context.Category_Locale (Posix_Tools.Commands.Contexts.Time)));

      Posix_Tools.Commands.Helpers.Finish (Context, Result);
   end Run;

end Posix_Tools.Commands.Date;
