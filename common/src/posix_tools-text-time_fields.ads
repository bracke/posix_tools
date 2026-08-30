package Posix_Tools.Text.Time_Fields
  with SPARK_Mode => On
is
   type Parsed_Time is record
      Valid  : Boolean := False;
      Hour   : Natural := 0;
      Minute : Natural := 0;
      Second : Natural := 0;
   end record;

   type Parsed_Time_Offset is record
      Valid   : Boolean := False;
      Minutes : Integer := 0;
   end record;

   function Days_In_Month (Year, Month : Natural) return Natural
     with
       Pre  => Month in 1 .. 12,
       Post => Days_In_Month'Result in 28 .. 31;

   function Day_Of_Year (Year, Month, Day : Natural) return Natural
     with
       Pre =>
         Month in 1 .. 12
         and then Day in 1 .. Days_In_Month (Year, Month),
       Post => Day_Of_Year'Result in 1 .. 366;

   function Is_Leap_Year (Year : Natural) return Boolean
     with
       Post =>
         Is_Leap_Year'Result =
           ((Year mod 4 = 0 and then Year mod 100 /= 0) or else Year mod 400 = 0);

   function Parse_HM_Or_HMS (Value : String) return Parsed_Time
     with
       Pre  => Value'First >= 1,
       Post =>
         (if Parse_HM_Or_HMS'Result.Valid then
            Parse_HM_Or_HMS'Result.Hour <= 23
            and then Parse_HM_Or_HMS'Result.Minute <= 59
            and then Parse_HM_Or_HMS'Result.Second <= 59
          else
            Parse_HM_Or_HMS'Result.Hour = 0
            and then Parse_HM_Or_HMS'Result.Minute = 0
            and then Parse_HM_Or_HMS'Result.Second = 0);

   function Parse_ISO_Time_Zone_Offset (Value : String) return Parsed_Time_Offset
     with
       Post =>
         (if Parse_ISO_Time_Zone_Offset'Result.Valid then
            Parse_ISO_Time_Zone_Offset'Result.Minutes in -1_439 .. 1_439
          else
            Parse_ISO_Time_Zone_Offset'Result.Minutes = 0);

   function Parse_POSIX_Time_Zone_Offset (Value : String) return Parsed_Time_Offset
     with
       Post =>
         (if Parse_POSIX_Time_Zone_Offset'Result.Valid then
            Parse_POSIX_Time_Zone_Offset'Result.Minutes in -1_439 .. 1_439
          else
            Parse_POSIX_Time_Zone_Offset'Result.Minutes = 0);
end Posix_Tools.Text.Time_Fields;
