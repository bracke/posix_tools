with Ada.Calendar.Formatting;
with Ada.Strings.Unbounded;
with Posix_Tools.Localization;
with Posix_Tools.Text.Numeric_Images;
with Posix_Tools.Text.Time_Fields;

package body Posix_Tools.Text.Date_Formats is
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Ada.Calendar.Formatting.Day_Name;

   LF : constant Character := Character'Val (10);

   package Images renames Posix_Tools.Text.Numeric_Images;

   type ISO_Week_Data is record
      Year : Natural;
      Week : Natural;
   end record;

   function Day_Of_Year (Year, Month, Day : Natural) return Natural
     renames Posix_Tools.Text.Time_Fields.Day_Of_Year;

   function Date_Text (Locale, Key, Default : String) return String;
   function ISO_Week_Day (Day : Ada.Calendar.Formatting.Day_Name) return Natural;
   function ISO_Week_For
     (Year  : Natural;
      Month : Natural;
      Day   : Natural) return ISO_Week_Data;
   function ISO_Weeks_In_Year (Year : Natural) return Natural;
   function Monday_Week_Number
     (Year  : Natural;
      Month : Natural;
      Day   : Natural) return Natural;
   function Month_Name (Locale : String; Month : Natural; Abbreviated : Boolean) return String;
   function Period_Name (Locale : String; Hour : Natural) return String;
   function Sunday_Week_Number
     (Year  : Natural;
      Month : Natural;
      Day   : Natural) return Natural;
   function Week_Day_For (Year, Month, Day : Natural) return Ada.Calendar.Formatting.Day_Name;
   function Week_Day_Name
     (Locale      : String;
      Day         : Ada.Calendar.Formatting.Day_Name;
      Abbreviated : Boolean) return String;

   function Date_Text (Locale, Key, Default : String) return String is
   begin
      return Posix_Tools.Localization.Text (Locale, "posix_tools.date." & Key, Default);
   end Date_Text;

   function Format_Date
     (Format           : String;
      Time             : Ada.Calendar.Time;
      Time_Zone_Offset : Ada.Calendar.Time_Zones.Time_Offset;
      Time_Zone_Name   : String := "";
      Locale           : String := "") return String
   is
      Year : Ada.Calendar.Year_Number;
      Month : Ada.Calendar.Month_Number;
      Day : Ada.Calendar.Day_Number;
      Split_Hour : Ada.Calendar.Formatting.Hour_Number;
      Split_Minute : Ada.Calendar.Formatting.Minute_Number;
      Split_Second : Ada.Calendar.Formatting.Second_Number;
      Sub_Second : Ada.Calendar.Formatting.Second_Duration;
      Hour : Natural;
      Hour_12 : Natural;
      Minute : Natural;
      Second : Natural;
      Week_Day : Ada.Calendar.Formatting.Day_Name;
      Output : Unbounded_String;
      I : Positive := Format'First;

      function Epoch_Seconds_Image return String;
      function Time_Zone_Image return String;

      function Epoch_Seconds_Image return String is
         Epoch : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
      begin
         return Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
           (Long_Long_Integer (Time - Epoch));
      end Epoch_Seconds_Image;

      function Time_Zone_Image return String is
         Minutes : constant Integer := Integer (Time_Zone_Offset);
         Absolute_Minutes : constant Natural :=
           (if Minutes < 0 then Natural (-Minutes) else Natural (Minutes));
         Hours : constant Natural := Absolute_Minutes / 60;
         Remaining_Minutes : constant Natural := Absolute_Minutes mod 60;
      begin
         return
           (if Minutes < 0 then "-" else "+")
           & Images.Two_Digit_Image (Hours)
           & Images.Two_Digit_Image (Remaining_Minutes);
      end Time_Zone_Image;
   begin
      Ada.Calendar.Formatting.Split
        (Time, Year, Month, Day, Split_Hour, Split_Minute, Split_Second, Sub_Second, Time_Zone_Offset);
      Hour := Natural (Split_Hour);
      Hour_12 := Hour mod 12;
      if Hour_12 = 0 then
         Hour_12 := 12;
      end if;
      Minute := Natural (Split_Minute);
      Second := Natural (Split_Second);
      Week_Day := Week_Day_For (Natural (Year), Natural (Month), Natural (Day));

      while I <= Format'Last loop
         if Format (I) = '%' and then I < Format'Last then
            case Format (I + 1) is
               when 'a' => Append (Output, Week_Day_Name (Locale, Week_Day, True));
               when 'A' => Append (Output, Week_Day_Name (Locale, Week_Day, False));
               when 'b' | 'h' => Append (Output, Month_Name (Locale, Natural (Month), True));
               when 'B' => Append (Output, Month_Name (Locale, Natural (Month), False));
               when 'C' => Append (Output, Images.Two_Digit_Image (Natural (Year) / 100));
               when 'Y' => Append (Output, Images.Four_Digit_Image (Natural (Year)));
               when 'y' => Append (Output, Images.Two_Digit_Image (Natural (Year) mod 100));
               when 'm' => Append (Output, Images.Two_Digit_Image (Natural (Month)));
               when 'd' => Append (Output, Images.Two_Digit_Image (Natural (Day)));
               when 'e' => Append (Output, Images.Space_Two_Image (Natural (Day)));
               when 'H' => Append (Output, Images.Two_Digit_Image (Hour));
               when 'I' => Append (Output, Images.Two_Digit_Image (Hour_12));
               when 'k' => Append (Output, Images.Space_Two_Image (Hour));
               when 'l' => Append (Output, Images.Space_Two_Image (Hour_12));
               when 'M' => Append (Output, Images.Two_Digit_Image (Minute));
               when 'p' => Append (Output, Period_Name (Locale, Hour));
               when 'S' => Append (Output, Images.Two_Digit_Image (Second));
               when 's' => Append (Output, Epoch_Seconds_Image);
               when 'j' =>
                  Append
                    (Output,
                     Images.Three_Digit_Image
                       (Day_Of_Year (Natural (Year), Natural (Month), Natural (Day))));
               when 'u' =>
                  Append (Output, Images.Natural_Image (Ada.Calendar.Formatting.Day_Name'Pos (Week_Day) + 1));
               when 'U' =>
                  Append
                    (Output,
                     Images.Two_Digit_Image
                       (Sunday_Week_Number (Natural (Year), Natural (Month), Natural (Day))));
               when 'V' =>
                  Append
                    (Output,
                     Images.Two_Digit_Image
                       (ISO_Week_For (Natural (Year), Natural (Month), Natural (Day)).Week));
               when 'W' =>
                  Append
                    (Output,
                     Images.Two_Digit_Image
                       (Monday_Week_Number (Natural (Year), Natural (Month), Natural (Day))));
               when 'G' =>
                  Append
                    (Output,
                     Images.Four_Digit_Image
                       (ISO_Week_For (Natural (Year), Natural (Month), Natural (Day)).Year));
               when 'g' =>
                  Append
                    (Output,
                     Images.Two_Digit_Image
                       (ISO_Week_For (Natural (Year), Natural (Month), Natural (Day)).Year mod 100));
               when 'z' => Append (Output, Time_Zone_Image);
               when 'Z' => Append (Output, (if Time_Zone_Name = "" then Time_Zone_Image else Time_Zone_Name));
               when 'w' =>
                  Append
                    (Output,
                     Images.Natural_Image
                       ((if Week_Day = Ada.Calendar.Formatting.Sunday
                         then 0
                         else Ada.Calendar.Formatting.Day_Name'Pos (Week_Day) + 1)));
               when 'D' =>
                  Append
                    (Output,
                     Images.Two_Digit_Image (Natural (Month)) & "/"
                     & Images.Two_Digit_Image (Natural (Day)) & "/"
                     & Images.Two_Digit_Image (Natural (Year) mod 100));
               when 'c' =>
                  Append
                    (Output,
                     Week_Day_Name (Locale, Week_Day, True) & " "
                     & Month_Name (Locale, Natural (Month), True) & " "
                     & Images.Space_Two_Image (Natural (Day)) & " "
                     & Images.Two_Digit_Image (Hour) & ":"
                     & Images.Two_Digit_Image (Minute) & ":"
                     & Images.Two_Digit_Image (Second) & " "
                     & Images.Four_Digit_Image (Natural (Year)));
               when 'F' =>
                  Append
                    (Output,
                     Images.Four_Digit_Image (Natural (Year)) & "-"
                     & Images.Two_Digit_Image (Natural (Month)) & "-"
                     & Images.Two_Digit_Image (Natural (Day)));
               when 'R' =>
                  Append (Output, Images.Two_Digit_Image (Hour) & ":" & Images.Two_Digit_Image (Minute));
               when 'r' =>
                  Append
                    (Output,
                     Images.Two_Digit_Image (Hour_12) & ":"
                     & Images.Two_Digit_Image (Minute) & ":"
                     & Images.Two_Digit_Image (Second) & " "
                     & Period_Name (Locale, Hour));
               when 'T' =>
                  Append
                    (Output,
                     Images.Two_Digit_Image (Hour) & ":"
                     & Images.Two_Digit_Image (Minute) & ":"
                     & Images.Two_Digit_Image (Second));
               when 'X' =>
                  Append
                    (Output,
                     Images.Two_Digit_Image (Hour) & ":"
                     & Images.Two_Digit_Image (Minute) & ":"
                     & Images.Two_Digit_Image (Second));
               when 'x' =>
                  Append
                    (Output,
                     Images.Two_Digit_Image (Natural (Month)) & "/"
                     & Images.Two_Digit_Image (Natural (Day)) & "/"
                     & Images.Two_Digit_Image (Natural (Year) mod 100));
               when '%' => Append (Output, "%");
               when 'n' => Append (Output, LF);
               when 't' => Append (Output, Character'Val (9));
               when others =>
                  Append (Output, "%" & Format (I + 1));
            end case;
            I := I + 2;
         else
            Append (Output, Format (I));
            I := I + 1;
         end if;
      end loop;

      return To_String (Output);
   end Format_Date;

   function ISO_Week_Day (Day : Ada.Calendar.Formatting.Day_Name) return Natural is
   begin
      if Day = Ada.Calendar.Formatting.Sunday then
         return 7;
      else
         return Ada.Calendar.Formatting.Day_Name'Pos (Day) + 1;
      end if;
   end ISO_Week_Day;

   function ISO_Week_For
     (Year  : Natural;
      Month : Natural;
      Day   : Natural) return ISO_Week_Data
   is
      Week_Day : constant Natural := ISO_Week_Day (Week_Day_For (Year, Month, Day));
      Ordinal  : constant Natural := Day_Of_Year (Year, Month, Day);
      Week     : Integer := (Integer (Ordinal) - Integer (Week_Day) + 10) / 7;
      ISO_Year : Natural := Year;
   begin
      if Week < 1 then
         ISO_Year := Year - 1;
         Week := Integer (ISO_Weeks_In_Year (ISO_Year));
      elsif Week > Integer (ISO_Weeks_In_Year (Year)) then
         ISO_Year := Year + 1;
         Week := 1;
      end if;

      return (Year => ISO_Year, Week => Natural (Week));
   end ISO_Week_For;

   function ISO_Weeks_In_Year (Year : Natural) return Natural is
      Jan_One : constant Ada.Calendar.Formatting.Day_Name := Week_Day_For (Year, 1, 1);
   begin
      if Jan_One = Ada.Calendar.Formatting.Thursday
        or else (Jan_One = Ada.Calendar.Formatting.Wednesday
                 and then ((Year mod 4 = 0 and then Year mod 100 /= 0) or else Year mod 400 = 0))
      then
         return 53;
      else
         return 52;
      end if;
   end ISO_Weeks_In_Year;

   function Monday_Week_Number
     (Year  : Natural;
      Month : Natural;
      Day   : Natural) return Natural
   is
      Ordinal : constant Natural := Day_Of_Year (Year, Month, Day);
      Week_Day : constant Ada.Calendar.Formatting.Day_Name := Week_Day_For (Year, Month, Day);
      Monday_Based_Day : constant Natural :=
        (if Week_Day = Ada.Calendar.Formatting.Sunday
         then 6
         else Ada.Calendar.Formatting.Day_Name'Pos (Week_Day));
   begin
      return (Ordinal + 6 - Monday_Based_Day) / 7;
   end Monday_Week_Number;

   function Month_Name (Locale : String; Month : Natural; Abbreviated : Boolean) return String is
   begin
      case Month is
         when 1 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.january" else "month.full.january"),
               (if Abbreviated then "Jan" else "January"));
         when 2 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.february" else "month.full.february"),
               (if Abbreviated then "Feb" else "February"));
         when 3 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.march" else "month.full.march"),
               (if Abbreviated then "Mar" else "March"));
         when 4 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.april" else "month.full.april"),
               (if Abbreviated then "Apr" else "April"));
         when 5 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.may" else "month.full.may"),
               "May");
         when 6 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.june" else "month.full.june"),
               (if Abbreviated then "Jun" else "June"));
         when 7 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.july" else "month.full.july"),
               (if Abbreviated then "Jul" else "July"));
         when 8 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.august" else "month.full.august"),
               (if Abbreviated then "Aug" else "August"));
         when 9 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.september" else "month.full.september"),
               (if Abbreviated then "Sep" else "September"));
         when 10 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.october" else "month.full.october"),
               (if Abbreviated then "Oct" else "October"));
         when 11 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.november" else "month.full.november"),
               (if Abbreviated then "Nov" else "November"));
         when 12 =>
            return Date_Text
              (Locale,
               (if Abbreviated then "month.abbrev.december" else "month.full.december"),
               (if Abbreviated then "Dec" else "December"));
         when others => return "";
      end case;
   end Month_Name;

   function Period_Name (Locale : String; Hour : Natural) return String is
   begin
      return
        Date_Text
          (Locale,
           (if Hour < 12 then "period.am" else "period.pm"),
           (if Hour < 12 then "AM" else "PM"));
   end Period_Name;

   function Sunday_Week_Number
     (Year  : Natural;
      Month : Natural;
      Day   : Natural) return Natural
   is
      Ordinal : constant Natural := Day_Of_Year (Year, Month, Day);
      Week_Day : constant Ada.Calendar.Formatting.Day_Name := Week_Day_For (Year, Month, Day);
      Sunday_Based_Day : constant Natural :=
        (if Week_Day = Ada.Calendar.Formatting.Sunday
         then 0
         else Ada.Calendar.Formatting.Day_Name'Pos (Week_Day) + 1);
   begin
      return (Ordinal + 6 - Sunday_Based_Day) / 7;
   end Sunday_Week_Number;

   function Week_Day_For (Year, Month, Day : Natural) return Ada.Calendar.Formatting.Day_Name is
      Offsets : constant array (1 .. 12) of Natural := [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4];
      Adjusted_Year : Natural := Year;
      Day_Index : Natural;
   begin
      if Month < 3 then
         Adjusted_Year := Adjusted_Year - 1;
      end if;

      Day_Index :=
        (Adjusted_Year
         + Adjusted_Year / 4
         - Adjusted_Year / 100
         + Adjusted_Year / 400
         + Offsets (Month)
         + Day) mod 7;

      if Day_Index = 0 then
         return Ada.Calendar.Formatting.Sunday;
      else
         return Ada.Calendar.Formatting.Day_Name'Val (Day_Index - 1);
      end if;
   end Week_Day_For;

   function Week_Day_Name
     (Locale      : String;
      Day         : Ada.Calendar.Formatting.Day_Name;
      Abbreviated : Boolean) return String is
   begin
      case Day is
         when Ada.Calendar.Formatting.Monday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.monday" else "weekday.full.monday"),
               (if Abbreviated then "Mon" else "Monday"));
         when Ada.Calendar.Formatting.Tuesday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.tuesday" else "weekday.full.tuesday"),
               (if Abbreviated then "Tue" else "Tuesday"));
         when Ada.Calendar.Formatting.Wednesday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.wednesday" else "weekday.full.wednesday"),
               (if Abbreviated then "Wed" else "Wednesday"));
         when Ada.Calendar.Formatting.Thursday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.thursday" else "weekday.full.thursday"),
               (if Abbreviated then "Thu" else "Thursday"));
         when Ada.Calendar.Formatting.Friday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.friday" else "weekday.full.friday"),
               (if Abbreviated then "Fri" else "Friday"));
         when Ada.Calendar.Formatting.Saturday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.saturday" else "weekday.full.saturday"),
               (if Abbreviated then "Sat" else "Saturday"));
         when Ada.Calendar.Formatting.Sunday =>
            return Date_Text
              (Locale,
               (if Abbreviated then "weekday.abbrev.sunday" else "weekday.full.sunday"),
               (if Abbreviated then "Sun" else "Sunday"));
      end case;
   end Week_Day_Name;
end Posix_Tools.Text.Date_Formats;
