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

   --  The time now. A command reads it once and works from that value, so
   --  that everything it does in one run is relative to the same instant.
   function Now return Ada.Calendar.Time;

   function Set_System_Time (Time : Ada.Calendar.Time) return Boolean;
end Posix_Tools.Host_Adapters.Clock;
