with Ada.Calendar.Formatting;

package body Posix_Tools.Unix_Time is
   use type Ada.Calendar.Time;

   function Epoch return Ada.Calendar.Time is
     (Ada.Calendar.Formatting.Time_Of (1970, 1, 1, 0.0, Time_Zone => 0));

   function Seconds_Of
     (Year, Month, Day, Hour, Minute, Second : Integer) return Long_Long_Integer
   is
      --  Days from 1970-01-01 to the date, counting years from March so
      --  that a leap day comes last.
      Adjusted_Year  : constant Long_Long_Integer :=
        Long_Long_Integer (Year) - (if Month <= 2 then 1 else 0);
      Adjusted_Month : constant Long_Long_Integer :=
        Long_Long_Integer (Month) + (if Month > 2 then -3 else 9);
      Era            : constant Long_Long_Integer :=
        (if Adjusted_Year >= 0 then Adjusted_Year else Adjusted_Year - 399) / 400;
      Year_Of_Era    : constant Long_Long_Integer := Adjusted_Year - Era * 400;
      Day_Of_Year    : constant Long_Long_Integer :=
        (153 * Adjusted_Month + 2) / 5 + Long_Long_Integer (Day) - 1;
      Day_Of_Era     : constant Long_Long_Integer :=
        Year_Of_Era * 365 + Year_Of_Era / 4 - Year_Of_Era / 100 + Day_Of_Year;
      Days           : constant Long_Long_Integer := Era * 146_097 + Day_Of_Era - 719_468;
   begin
      return Days * 86_400
        + Long_Long_Integer (Hour) * 3_600
        + Long_Long_Integer (Minute) * 60
        + Long_Long_Integer (Second);
   end Seconds_Of;

   function Seconds_Since_Epoch (Time : Ada.Calendar.Time) return Long_Long_Integer is
      Year       : Ada.Calendar.Year_Number;
      Month      : Ada.Calendar.Month_Number;
      Day        : Ada.Calendar.Day_Number;
      Hour       : Ada.Calendar.Formatting.Hour_Number;
      Minute     : Ada.Calendar.Formatting.Minute_Number;
      Second     : Ada.Calendar.Formatting.Second_Number;
      Sub_Second : Ada.Calendar.Formatting.Second_Duration;
   begin
      --  Split drops the fraction of a second: the count is truncated.
      Ada.Calendar.Formatting.Split (Time, Year, Month, Day, Hour, Minute, Second, Sub_Second, Time_Zone => 0);
      return Seconds_Of (Year, Month, Day, Hour, Minute, Second);
   end Seconds_Since_Epoch;

   function Time_Of (Seconds : Long_Long_Integer) return Ada.Calendar.Time is
     (Epoch + Duration (Seconds));
end Posix_Tools.Unix_Time;
