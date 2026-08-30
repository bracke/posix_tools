with Ada.Directories;
with GNAT.OS_Lib;
with Hostkit.Metadata;

package body Posix_Tools.Host_Adapters.File_System.Times is
   function Epoch_Seconds (Time : File_Time) return Long_Long_Integer is
      Year   : GNAT.OS_Lib.Year_Type;
      Month  : GNAT.OS_Lib.Month_Type;
      Day    : GNAT.OS_Lib.Day_Type;
      Hour   : GNAT.OS_Lib.Hour_Type;
      Minute : GNAT.OS_Lib.Minute_Type;
      Second : GNAT.OS_Lib.Second_Type;

      function Days_Before_Unix_Epoch
        (Year  : Long_Long_Integer;
         Month : Long_Long_Integer;
         Day   : Long_Long_Integer)
         return Long_Long_Integer
      is
         Adjusted_Year  : Long_Long_Integer := Year;
         Adjusted_Month : Long_Long_Integer := Month;
         Era            : Long_Long_Integer;
         Year_Of_Era    : Long_Long_Integer;
         Day_Of_Year    : Long_Long_Integer;
         Day_Of_Era     : Long_Long_Integer;
      begin
         if Adjusted_Month <= 2 then
            Adjusted_Year := Adjusted_Year - 1;
         end if;

         Era := (if Adjusted_Year >= 0 then Adjusted_Year else Adjusted_Year - 399) / 400;
         Year_Of_Era := Adjusted_Year - Era * 400;
         Adjusted_Month := Adjusted_Month + (if Adjusted_Month > 2 then -3 else 9);
         Day_Of_Year := (153 * Adjusted_Month + 2) / 5 + Day - 1;
         Day_Of_Era := Year_Of_Era * 365 + Year_Of_Era / 4 - Year_Of_Era / 100 + Day_Of_Year;
         return Era * 146_097 + Day_Of_Era - 719_468;
      end Days_Before_Unix_Epoch;
   begin
      GNAT.OS_Lib.GM_Split (GNAT.OS_Lib.OS_Time (Time), Year, Month, Day, Hour, Minute, Second);
      return Days_Before_Unix_Epoch
          (Long_Long_Integer (Year), Long_Long_Integer (Month), Long_Long_Integer (Day))
        * 86_400
        + Long_Long_Integer (Hour) * 3_600
        + Long_Long_Integer (Minute) * 60
        + Long_Long_Integer (Second);
   end Epoch_Seconds;

   function Access_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean is
      Available : Boolean := False;
   begin
      Time := Hostkit.Metadata.File_Access_Time (Path, Available);
      return Available;
   exception
      when others =>
         Time := Ada.Calendar.Time_Of (1901, 1, 1);
         return False;
   end Access_Time;

   function Copy_File_Times (Source : String; Target : String) return Boolean is
      Source_Access_Time       : File_Time;
      Source_Modification_Time : File_Time;
   begin
      if not File_Access_Time_From_File (Source, Source_Access_Time)
        or else not File_Time_From_File (Source, Source_Modification_Time)
      then
         return False;
      end if;

      return Set_File_Times (Target, Source_Access_Time, Source_Modification_Time);
   exception
      when others =>
         return False;
   end Copy_File_Times;

   function Copy_Modification_Time (Source : String; Target : String) return Boolean is
   begin
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp (Target, GNAT.OS_Lib.File_Time_Stamp (Source));
      return True;
   exception
      when others =>
         return False;
   end Copy_Modification_Time;

   function Creation_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean is
      Available : Boolean := False;
   begin
      Time := Hostkit.Metadata.File_Creation_Time (Path, Available);
      return Available;
   exception
      when others =>
         Time := Ada.Calendar.Time_Of (1901, 1, 1);
         return False;
   end Creation_Time;

   function Current_File_Time return File_Time is
   begin
      return File_Time (GNAT.OS_Lib.Current_Time);
   end Current_File_Time;

   function File_Access_Time_From_File (Path : String; Time : out File_Time) return Boolean is
      Available : Boolean;
      Value     : constant Ada.Calendar.Time := Hostkit.Metadata.File_Access_Time (Path, Available);
      Year      : Ada.Calendar.Year_Number;
      Month     : Ada.Calendar.Month_Number;
      Day       : Ada.Calendar.Day_Number;
      Seconds   : Duration;
      Whole     : Natural;
   begin
      Ada.Calendar.Split (Value, Year, Month, Day, Seconds);
      Whole := Natural (Seconds);
      Time :=
        File_Time
          (GNAT.OS_Lib.GM_Time_Of
             (GNAT.OS_Lib.Year_Type (Year),
              GNAT.OS_Lib.Month_Type (Month),
              GNAT.OS_Lib.Day_Type (Day),
              GNAT.OS_Lib.Hour_Type (Whole / 3_600),
              GNAT.OS_Lib.Minute_Type ((Whole mod 3_600) / 60),
              GNAT.OS_Lib.Second_Type (Whole mod 60)));
      return Available;
   exception
      when others =>
         Time := Current_File_Time;
         return False;
   end File_Access_Time_From_File;

   function File_Time_From_File (Path : String; Time : out File_Time) return Boolean is
   begin
      Time := File_Time (GNAT.OS_Lib.File_Time_Stamp (Path));
      return True;
   exception
      when others =>
         Time := Current_File_Time;
         return False;
   end File_Time_From_File;

   function File_Time_Of
     (Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Time   : out File_Time) return Boolean
   is
      use type GNAT.OS_Lib.OS_Time;
      Candidate : GNAT.OS_Lib.OS_Time;
   begin
      Candidate :=
        GNAT.OS_Lib.GM_Time_Of
          (GNAT.OS_Lib.Year_Type (Year),
           GNAT.OS_Lib.Month_Type (Month),
           GNAT.OS_Lib.Day_Type (Day),
           GNAT.OS_Lib.Hour_Type (Hour),
           GNAT.OS_Lib.Minute_Type (Minute),
           GNAT.OS_Lib.Second_Type (Second));
      Time := File_Time (Candidate);
      return Candidate /= GNAT.OS_Lib.Invalid_Time;
   exception
      when others =>
         Time := Current_File_Time;
         return False;
   end File_Time_Of;

   function Modification_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean is
   begin
      Time := Ada.Directories.Modification_Time (Path);
      return True;
   exception
      when others =>
         Time := Ada.Calendar.Time_Of (Year => 1901, Month => 1, Day => 1);
         return False;
   end Modification_Time;

   function Set_Access_Time (Path : String; Time : File_Time) return Boolean is
      Path_Modification_Time : File_Time;
   begin
      if not File_Time_From_File (Path, Path_Modification_Time) then
         return False;
      end if;

      return Set_File_Times (Path, Time, Path_Modification_Time);
   exception
      when others =>
         return False;
   end Set_Access_Time;

   function Set_File_Times (Path : String; Access_Time, Modified_Time : File_Time) return Boolean is
   begin
      return Hostkit.Metadata.Set_File_Times
        (Path,
         Epoch_Seconds (Access_Time),
         Epoch_Seconds (Modified_Time));
   exception
      when others =>
         return False;
   end Set_File_Times;

   function Set_Modification_Time (Path : String; Time : File_Time) return Boolean is
      Path_Access_Time : File_Time;
   begin
      if not File_Access_Time_From_File (Path, Path_Access_Time) then
         Path_Access_Time := Current_File_Time;
      end if;

      return Set_File_Times (Path, Path_Access_Time, Time);
   exception
      when others =>
         return False;
   end Set_Modification_Time;
end Posix_Tools.Host_Adapters.File_System.Times;
