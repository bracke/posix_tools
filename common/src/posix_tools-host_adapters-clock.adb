with Hostkit.Clock;

package body Posix_Tools.Host_Adapters.Clock is
   function Set_System_Time (Time : Ada.Calendar.Time) return Boolean is
   begin
      return Hostkit.Clock.Set_System_Time (Time);
   end Set_System_Time;
end Posix_Tools.Host_Adapters.Clock;
