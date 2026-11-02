with Ada.Calendar;

--  Times as seconds since the Unix epoch, 1970-01-01 00:00:00 UTC, the
--  count stat, find and date's %s show, whatever the local time zone.
package Posix_Tools.Unix_Time is
   --  The epoch, as an Ada.Calendar.Time.
   function Epoch return Ada.Calendar.Time;

   --  The seconds from the epoch to the UTC date and time given, in the
   --  proleptic Gregorian calendar.
   function Seconds_Of
     (Year, Month, Day, Hour, Minute, Second : Integer) return Long_Long_Integer
     with Pre => Month in 1 .. 12;

   --  Whole seconds from the epoch to Time, truncated toward the past:
   --  half a second before the epoch is -1.
   function Seconds_Since_Epoch (Time : Ada.Calendar.Time) return Long_Long_Integer;

   --  The time Seconds after the epoch.
   function Time_Of (Seconds : Long_Long_Integer) return Ada.Calendar.Time;
end Posix_Tools.Unix_Time;
