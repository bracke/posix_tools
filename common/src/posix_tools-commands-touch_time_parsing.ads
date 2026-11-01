with Ada.Calendar;
with Posix_Tools.Host_Adapters.File_System;

--  touch's -t and -d time operands. Now is the time touch was run: the year
--  -t leaves out, and the day and the offsets -d is relative to, come from
--  it alone, so one operand never sees two different times.
package Posix_Tools.Commands.Touch_Time_Parsing is
   function Parse_Date_Time
     (Text   : String;
      Now    : Ada.Calendar.Time;
      Parsed : out Posix_Tools.Host_Adapters.File_System.File_Time) return Boolean;

   function Parse_Explicit_Time
     (Text   : String;
      Now    : Ada.Calendar.Time;
      Parsed : out Posix_Tools.Host_Adapters.File_System.File_Time) return Boolean;
end Posix_Tools.Commands.Touch_Time_Parsing;
