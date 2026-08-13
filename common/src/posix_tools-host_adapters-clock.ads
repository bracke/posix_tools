with Ada.Calendar;

package Posix_Tools.Host_Adapters.Clock is
   function Set_System_Time (Time : Ada.Calendar.Time) return Boolean;
end Posix_Tools.Host_Adapters.Clock;
