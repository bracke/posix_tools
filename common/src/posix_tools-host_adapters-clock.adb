with Hostkit.Clock;

package body Posix_Tools.Host_Adapters.Clock is
   function Resolve_Time_Zone
     (Name : String;
      Time : Ada.Calendar.Time;
      Offset : out Ada.Calendar.Time_Zones.Time_Offset;
      Zone_Name : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean
   is
      Info : constant Hostkit.Clock.Time_Zone_Info := Hostkit.Clock.Resolve_Time_Zone (Name, Time);
   begin
      if not Info.Available then
         return False;
      end if;

      Offset := Ada.Calendar.Time_Zones.Time_Offset (Info.Offset_Minutes);
      Zone_Name := Info.Name;
      return True;
   exception
      when others =>
         return False;
   end Resolve_Time_Zone;

   function Set_System_Time (Time : Ada.Calendar.Time) return Boolean is
   begin
      return Hostkit.Clock.Set_System_Time (Time);
   end Set_System_Time;
end Posix_Tools.Host_Adapters.Clock;
