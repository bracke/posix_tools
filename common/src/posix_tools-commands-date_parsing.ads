with Ada.Calendar;
with Ada.Calendar.Time_Zones;
with Ada.Strings.Unbounded;

package Posix_Tools.Commands.Date_Parsing is
   function Parse_Set_Date_Time
     (Text             : String;
      Current_Year     : Ada.Calendar.Year_Number;
      Time_Zone_Offset : Ada.Calendar.Time_Zones.Time_Offset;
      Parsed           : out Ada.Calendar.Time) return Boolean;

   function Resolve_Time_Zone
     (Value          : String;
      Reference_Time : Ada.Calendar.Time;
      Locale         : String;
      Offset         : out Ada.Calendar.Time_Zones.Time_Offset;
      Zone_Name      : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
end Posix_Tools.Commands.Date_Parsing;
