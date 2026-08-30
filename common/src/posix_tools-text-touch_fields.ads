package Posix_Tools.Text.Touch_Fields
  with SPARK_Mode => On
is
   subtype Month_Index is Natural range 0 .. 12;
   subtype Normalized_Date_Time_Length is Natural range 0 .. 25;
   subtype Normalized_Date_Time_Buffer is String (1 .. 25);
   subtype Relative_Direction is Integer range -1 .. 1;
   subtype Unit_Seconds_Value is Long_Long_Integer range 0 .. 604_800;
   subtype Weekday_Index is Natural range 0 .. 7;

   type Normalized_Date_Time is record
      Valid   : Boolean := False;
      Changed : Boolean := False;
      Length  : Normalized_Date_Time_Length := 0;
      Text    : Normalized_Date_Time_Buffer := [others => ' '];
   end record;

   function Is_Ago (Name : String) return Boolean;

   function Month_Number (Name : String) return Month_Index;

   function Normalize_ISO_Date_Time (Text : String) return Normalized_Date_Time
     with
       Pre =>
         Text'First in Positive
         and then Text'First <= Positive'Last - 19
         and then Text'Last < Positive'Last,
       Post =>
         (if Normalize_ISO_Date_Time'Result.Valid then
            Normalize_ISO_Date_Time'Result.Changed
          else
            not Normalize_ISO_Date_Time'Result.Changed
            and then Normalize_ISO_Date_Time'Result.Length = 0);

   function Relative_Direction_For (Name : String) return Relative_Direction;

   function Unit_Seconds (Name : String) return Unit_Seconds_Value;

   function Valid_POSIX_Timestamp (Text : String) return Boolean
     with
       Pre =>
         Text'First in Positive
         and then Text'Last < Positive'Last,
       Post =>
         (if Text = "" then not Valid_POSIX_Timestamp'Result);

   function Weekday_Number (Name : String) return Weekday_Index;
end Posix_Tools.Text.Touch_Fields;
