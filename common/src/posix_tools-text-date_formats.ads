with Ada.Calendar;
with Ada.Calendar.Time_Zones;

package Posix_Tools.Text.Date_Formats is
   function Format_Date
     (Format           : String;
      Time             : Ada.Calendar.Time;
      Time_Zone_Offset : Ada.Calendar.Time_Zones.Time_Offset;
      Time_Zone_Name   : String := "";
      Locale           : String := "") return String;
end Posix_Tools.Text.Date_Formats;
