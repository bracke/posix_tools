with Ada.Calendar;
with Ada.Calendar.Time_Zones;
with Ada.Strings.Unbounded;

package Posix_Tools.Host_Adapters.Clock is
   function Resolve_Time_Zone
     (Name : String;
      Time : Ada.Calendar.Time;
      Offset : out Ada.Calendar.Time_Zones.Time_Offset;
      Zone_Name : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean;

   function Set_System_Time (Time : Ada.Calendar.Time) return Boolean;
end Posix_Tools.Host_Adapters.Clock;
