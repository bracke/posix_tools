with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Date_Parsing;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Date_Formats;

package body Posix_Tools.Commands.Date is
   use Ada.Strings.Unbounded;

   procedure Set_Success
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result) is
   begin
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Set_Success;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Time_Zone_Offset : Ada.Calendar.Time_Zones.Time_Offset :=
        Ada.Calendar.Time_Zones.UTC_Time_Offset (Now);
      Time_Zone_Name : Unbounded_String;
      Has_Format : Boolean := False;
      Format_Arg : Unbounded_String;
      Has_Set_Time : Boolean := False;
      Set_Time : Ada.Calendar.Time := Now;
      TZ_Text : constant String := Context.Environment_Value ("TZ");
      Force_UTC : Boolean := False;
      End_Options : Boolean := False;

   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         if not End_Options and then Context.Argument (I) = "--" then
            End_Options := True;
         elsif not End_Options and then Context.Argument (I) = "-u" then
            Time_Zone_Offset := 0;
            Time_Zone_Name := To_Unbounded_String ("UTC");
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
            if Posix_Tools.Commands.Date_Parsing.Parse_Set_Date_Time
              (Context.Argument (I),
               Ada.Calendar.Year (Now),
               Time_Zone_Offset,
               Set_Time)
            then
               Has_Set_Time := True;
            else
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "invalid operand '" & Context.Argument (I) & "'");
               return;
            end if;
         else
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Context.Argument (I) & "'");
            return;
         end if;
      end loop;

      if TZ_Text /= "" and then not Force_UTC then
         declare
            Parsed_Offset : Ada.Calendar.Time_Zones.Time_Offset;
            Parsed_Name : Unbounded_String;
         begin
            if Posix_Tools.Commands.Date_Parsing.Resolve_Time_Zone
              (TZ_Text,
               (if Has_Set_Time then Set_Time else Now),
               Context.Effective_Locale,
               Parsed_Offset,
               Parsed_Name)
            then
               Time_Zone_Offset := Parsed_Offset;
               Time_Zone_Name := Parsed_Name;
            end if;
         end;
      end if;

      if Has_Set_Time and then not Context.Set_System_Date_Time (Set_Time) then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.date.set_failed", "cannot set system date");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      if Has_Format then
         Context.Put_Line
           (Posix_Tools.Text.Date_Formats.Format_Date
              (To_String (Format_Arg),
               (if Has_Set_Time then Set_Time else Now),
               Time_Zone_Offset,
               To_String (Time_Zone_Name),
               Context.Effective_Locale));
      else
         Context.Put_Line
           (Ada.Calendar.Formatting.Image
              ((if Has_Set_Time then Set_Time else Now),
               Time_Zone => Time_Zone_Offset));
      end if;

      Set_Success (Context, Result);
   end Run;

end Posix_Tools.Commands.Date;
