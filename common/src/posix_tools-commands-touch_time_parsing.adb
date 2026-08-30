with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Time_Fields;
with Posix_Tools.Text.Touch_Fields;

package body Posix_Tools.Commands.Touch_Time_Parsing is
   use type Ada.Calendar.Time;
   use type Ada.Containers.Count_Type;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   function Calendar_To_File_Time
     (Value  : Ada.Calendar.Time;
      Parsed : out FS.File_Time) return Boolean;
   function Decimal_Value (Value : String; Result : out Natural) return Boolean;
   function Decimal_Value
     (Value  : String;
      Low    : Natural;
      High   : Natural;
      Result : out Natural) return Boolean;
   function Lowered (Value : String) return String;
   function Parse_Free_Form_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean;
   function Parse_ISO_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean;
   function Parse_Month_Name_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean;
   function Parse_Normalized_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean;
   function Parse_Offset
     (Text    : String;
      First   : Positive;
      Minutes : out Integer) return Boolean;
   function Parse_Time (Value : String; Hour, Minute, Second : out Natural) return Boolean;
   function Today_At (Seconds : Duration) return Ada.Calendar.Time;
   procedure Tokenize (Text : String; Tokens : in out String_Vectors.Vector);
   function Touch_Four_Digits (Text : String; First : Positive) return Natural;
   function Touch_Two_Digits (Text : String; First : Positive) return Natural;
   function Without_Trailing_Comma (Value : String) return String;

   function Calendar_To_File_Time
     (Value  : Ada.Calendar.Time;
      Parsed : out FS.File_Time) return Boolean
   is
      Year : Ada.Calendar.Year_Number;
      Month : Ada.Calendar.Month_Number;
      Day : Ada.Calendar.Day_Number;
      Seconds : Duration;
      Whole : Natural;
   begin
      Ada.Calendar.Split (Value, Year, Month, Day, Seconds);
      Whole := Natural (Seconds);
      return FS.File_Time_Of
        (Natural (Year),
         Natural (Month),
         Natural (Day),
         Whole / 3_600,
         (Whole mod 3_600) / 60,
         Whole mod 60,
         Parsed);
   end Calendar_To_File_Time;

   function Decimal_Value (Value : String; Result : out Natural) return Boolean is
      Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
        Posix_Tools.Text.Decimal_Parsing.Natural_Value (Value);
   begin
      Result := Parsed.Value;
      return Parsed.Valid;
   end Decimal_Value;

   function Decimal_Value
     (Value  : String;
      Low    : Natural;
      High   : Natural;
      Result : out Natural) return Boolean
   is
      Parsed : constant Posix_Tools.Text.Decimal_Parsing.Parsed_Natural :=
        Posix_Tools.Text.Decimal_Parsing.Natural_In_Range (Value, Low, High);
   begin
      if Parsed.Valid then
         Result := Parsed.Value;
         return True;
      else
         Result := 0;
         return False;
      end if;
   end Decimal_Value;

   function Lowered (Value : String) return String is
      Result : String := Value;
   begin
      for I in Result'Range loop
         if Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper (Result (I)) then
            Result (I) := Posix_Tools.Text.Byte_Classes.To_ASCII_Lower (Result (I));
         end if;
      end loop;
      return Result;
   end Lowered;

   function Parse_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
   begin
      return Parse_Explicit_Time (Text, Parsed)
        or else Parse_ISO_Date_Time (Text, Parsed)
        or else Parse_Normalized_Date_Time (Text, Parsed)
        or else Parse_Month_Name_Date_Time (Text, Parsed)
        or else Parse_Free_Form_Date_Time (Text, Parsed);
   end Parse_Date_Time;

   function Parse_Explicit_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
      Dot : Natural := 0;
   begin
      Parsed := FS.Current_File_Time;
      if not Posix_Tools.Text.Touch_Fields.Valid_POSIX_Timestamp (Text) then
         return False;
      end if;

      for I in Text'Range loop
         if Text (I) = '.' then
            Dot := I;
            exit;
         end if;
      end loop;

      declare
         Main_Last : constant Natural := (if Dot = 0 then Text'Last else Dot - 1);
         Main      : constant String := Text (Text'First .. Main_Last);
         YY        : Natural;
         Year      : Natural;
         Month     : constant Natural := Touch_Two_Digits (Main, Main'Last - 7);
         Day       : constant Natural := Touch_Two_Digits (Main, Main'Last - 5);
         Hour      : constant Natural := Touch_Two_Digits (Main, Main'Last - 3);
         Minute    : constant Natural := Touch_Two_Digits (Main, Main'Last - 1);
         Second    : constant Natural :=
           (if Dot = 0 then 0 else Touch_Two_Digits (Text, Dot + 1));
      begin
         if Second > 59 then
            return False;
         end if;

         if Main'Length = 8 then
            Year := Natural (Ada.Calendar.Year (Ada.Calendar.Clock));
         elsif Main'Length = 10 then
            YY := Touch_Two_Digits (Main, Main'First);
            Year := (if YY <= 68 then 2000 else 1900) + YY;
         elsif Main'Length = 12 then
            Year := 100 * Touch_Two_Digits (Main, Main'First)
              + Touch_Two_Digits (Main, Main'First + 2);
         else
            Year := 100 * Touch_Two_Digits (Main, Main'First)
              + Touch_Two_Digits (Main, Main'First + 2);
         end if;

         return FS.File_Time_Of (Year, Month, Day, Hour, Minute, Second, Parsed);
      end;
   exception
      when Constraint_Error =>
         return False;
   end Parse_Explicit_Time;

   function Parse_Free_Form_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
      Tokens : String_Vectors.Vector;
   begin
      Parsed := FS.Current_File_Time;
      if Text = "" then
         return False;
      end if;

      Tokenize (Text, Tokens);
      if Tokens.Length = 0 then
         return False;
      end if;

      declare
         First : constant String := Lowered (Tokens.Element (1));
         Direction : constant Integer :=
           Posix_Tools.Text.Touch_Fields.Relative_Direction_For (Tokens.Element (1));
      begin
         if Tokens.Length = 1 then
            if First = "now" then
               Parsed := FS.Current_File_Time;
               return True;
            elsif First = "today" then
               return Calendar_To_File_Time (Today_At (0.0), Parsed);
            elsif First = "yesterday" then
               return Calendar_To_File_Time (Today_At (0.0) - 86_400.0, Parsed);
            elsif First = "tomorrow" then
               return Calendar_To_File_Time (Today_At (0.0) + 86_400.0, Parsed);
            elsif First = "noon" then
               return Calendar_To_File_Time (Today_At (12.0 * 3_600.0), Parsed);
            elsif First = "midnight" then
               return Calendar_To_File_Time (Today_At (0.0), Parsed);
            end if;
         elsif Tokens.Length = 2 and then Direction /= 0 then
            declare
               Target : constant Natural :=
                 Posix_Tools.Text.Touch_Fields.Weekday_Number (Tokens.Element (2));
               Now_Day : constant Natural :=
                 (case Ada.Calendar.Formatting.Day_Of_Week (Ada.Calendar.Clock) is
                    when Ada.Calendar.Formatting.Monday => 1,
                    when Ada.Calendar.Formatting.Tuesday => 2,
                    when Ada.Calendar.Formatting.Wednesday => 3,
                    when Ada.Calendar.Formatting.Thursday => 4,
                    when Ada.Calendar.Formatting.Friday => 5,
                    when Ada.Calendar.Formatting.Saturday => 6,
                    when Ada.Calendar.Formatting.Sunday => 7);
               Day_Offset : Integer;
            begin
               if Target = 0 then
                  return False;
               end if;

               Day_Offset := Integer (Target) - Integer (Now_Day);
               if Direction > 0 and then Day_Offset <= 0 then
                  Day_Offset := Day_Offset + 7;
               elsif Direction < 0 and then Day_Offset >= 0 then
                  Day_Offset := Day_Offset - 7;
               end if;

               return Calendar_To_File_Time
                 (Today_At (0.0) + Duration (Day_Offset * 86_400), Parsed);
            end;
         elsif Tokens.Length = 2
           and then First'Length >= 2
           and then First (First'First) in '+' | '-'
         then
            declare
               Count : Natural;
               Sign : constant Long_Long_Integer := (if First (First'First) = '-' then -1 else 1);
               Unit : constant Long_Long_Integer :=
                 Posix_Tools.Text.Touch_Fields.Unit_Seconds (Tokens.Element (2));
            begin
               if Unit = 0
                 or else not Decimal_Value (First (First'First + 1 .. First'Last), Count)
               then
                  return False;
               end if;

               return Calendar_To_File_Time
                 (Ada.Calendar.Clock + Duration (Sign * Long_Long_Integer (Count) * Unit),
                  Parsed);
            end;
         elsif Tokens.Length = 3
           and then Posix_Tools.Text.Touch_Fields.Is_Ago (Tokens.Element (3))
         then
            declare
               Count : Natural;
               Unit : constant Long_Long_Integer :=
                 Posix_Tools.Text.Touch_Fields.Unit_Seconds (Tokens.Element (2));
            begin
               if Unit = 0 or else not Decimal_Value (Tokens.Element (1), Count) then
                  return False;
               end if;

               return Calendar_To_File_Time
                 (Ada.Calendar.Clock - Duration (Long_Long_Integer (Count) * Unit), Parsed);
            end;
         end if;
      end;

      return False;
   exception
      when Constraint_Error =>
         return False;
   end Parse_Free_Form_Date_Time;

   function Parse_ISO_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
      Date_Only : constant Boolean := Text'Length = 10;
      Minute_Precision : constant Boolean := Text'Length = 16;
      Second_Precision : constant Boolean := Text'Length = 19;
      Offset_Minute_Precision : constant Boolean :=
        (Text'Length in 17 | 19 | 21 | 22)
        and then (Text (Text'First + 16) = 'Z'
                  or else Text (Text'First + 16) in '+' | '-');
      Offset_Second_Precision : constant Boolean :=
        (Text'Length in 20 | 22 | 24 | 25)
        and then (Text (Text'First + 19) = 'Z'
                  or else Text (Text'First + 19) in '+' | '-');
      Offset_Precision : constant Boolean := Offset_Minute_Precision or else Offset_Second_Precision;
      Date_Time_Last : constant Natural :=
        (if Offset_Second_Precision then Text'First + 18
         elsif Offset_Minute_Precision then Text'First + 15
         else Text'Last);
      Offset_Minutes : Integer := 0;
   begin
      Parsed := FS.Current_File_Time;
      if not (Date_Only or else Minute_Precision or else Second_Precision or else Offset_Precision)
        or else Text (Text'First + 4) /= '-'
        or else Text (Text'First + 7) /= '-'
        or else ((Minute_Precision or else Second_Precision or else Offset_Precision)
                 and then Text (Text'First + 10) not in 'T' | ' ')
        or else ((Minute_Precision or else Second_Precision or else Offset_Precision)
                 and then Text (Text'First + 13) /= ':')
        or else ((Second_Precision or else Offset_Second_Precision) and then Text (Text'First + 16) /= ':')
      then
         return False;
      end if;

      for I in Text'First .. Date_Time_Last loop
         if I not in Text'First + 4 | Text'First + 7 | Text'First + 10 | Text'First + 13 | Text'First + 16
           and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I))
         then
            return False;
         end if;
      end loop;

      if not Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range
          (Text (Text'First + 5 .. Text'First + 6), 1, 12)
        or else not Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range
          (Text (Text'First + 8 .. Text'First + 9), 1, 31)
        or else ((Minute_Precision or else Second_Precision or else Offset_Precision)
                 and then not Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range
                   (Text (Text'First + 11 .. Text'First + 12), 0, 23))
        or else ((Minute_Precision or else Second_Precision or else Offset_Precision)
                 and then not Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range
                   (Text (Text'First + 14 .. Text'First + 15), 0, 59))
        or else ((Second_Precision or else Offset_Second_Precision)
                 and then not Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range
                   (Text (Text'First + 17 .. Text'First + 18), 0, 59))
        or else (Offset_Second_Precision
                 and then not Parse_Offset (Text, Text'First + 19, Offset_Minutes))
        or else (Offset_Minute_Precision
                 and then not Parse_Offset (Text, Text'First + 16, Offset_Minutes))
      then
         return False;
      end if;

      if Offset_Precision and then Offset_Minutes /= 0 then
         declare
            Normalized : constant Ada.Calendar.Time :=
              Ada.Calendar.Time_Of
                (Ada.Calendar.Year_Number (Touch_Four_Digits (Text, Text'First)),
                 Ada.Calendar.Month_Number (Touch_Two_Digits (Text, Text'First + 5)),
                 Ada.Calendar.Day_Number (Touch_Two_Digits (Text, Text'First + 8)),
                 Duration
                   (Touch_Two_Digits (Text, Text'First + 11) * 3_600
                    + Touch_Two_Digits (Text, Text'First + 14) * 60
                    + (if Offset_Second_Precision then Touch_Two_Digits (Text, Text'First + 17) else 0))
                 - Duration (Offset_Minutes * 60));
         begin
            return Calendar_To_File_Time (Normalized, Parsed);
         end;
      else
         return FS.File_Time_Of
           (Touch_Four_Digits (Text, Text'First),
            Touch_Two_Digits (Text, Text'First + 5),
            Touch_Two_Digits (Text, Text'First + 8),
            (if Date_Only then 0 else Touch_Two_Digits (Text, Text'First + 11)),
            (if Date_Only then 0 else Touch_Two_Digits (Text, Text'First + 14)),
            (if Second_Precision or else Offset_Second_Precision
             then Touch_Two_Digits (Text, Text'First + 17)
             else 0),
            Parsed);
      end if;
   exception
      when Constraint_Error =>
         return False;
   end Parse_ISO_Date_Time;

   function Parse_Month_Name_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
      Tokens : String_Vectors.Vector;
   begin
      Parsed := FS.Current_File_Time;
      if Text = "" then
         return False;
      end if;

      Tokenize (Text, Tokens);
      if Tokens.Length not in 3 | 4 then
         return False;
      end if;

      declare
         First_Month  : constant Natural :=
           Posix_Tools.Text.Touch_Fields.Month_Number (Tokens.Element (1));
         Second_Month : constant Natural :=
           (if Tokens.Length >= 2
            then Posix_Tools.Text.Touch_Fields.Month_Number (Tokens.Element (2))
            else 0);
         Month  : Natural;
         Day    : Natural;
         Year   : Natural;
         Hour   : Natural := 0;
         Minute : Natural := 0;
         Second : Natural := 0;
      begin
         if First_Month /= 0 then
            Month := First_Month;
            if not Decimal_Value (Without_Trailing_Comma (Tokens.Element (2)), 1, 31, Day) then
               return False;
            end if;
         elsif Second_Month /= 0 then
            Month := Second_Month;
            if not Decimal_Value (Without_Trailing_Comma (Tokens.Element (1)), 1, 31, Day) then
               return False;
            end if;
         else
            return False;
         end if;

         if not Decimal_Value (Tokens.Element (3), 1901, 2399, Year)
           or else (Tokens.Length = 4 and then not Parse_Time (Tokens.Element (4), Hour, Minute, Second))
         then
            return False;
         end if;

         return FS.File_Time_Of (Year, Month, Day, Hour, Minute, Second, Parsed);
      end;
   exception
      when Constraint_Error =>
         return False;
   end Parse_Month_Name_Date_Time;

   function Parse_Normalized_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
      Normalized : constant Posix_Tools.Text.Touch_Fields.Normalized_Date_Time :=
        Posix_Tools.Text.Touch_Fields.Normalize_ISO_Date_Time (Text);
   begin
      Parsed := FS.Current_File_Time;
      if not Normalized.Valid then
         return False;
      end if;

      return Parse_ISO_Date_Time (Normalized.Text (1 .. Normalized.Length), Parsed);
   exception
      when Constraint_Error =>
         return False;
   end Parse_Normalized_Date_Time;

   function Parse_Offset
     (Text    : String;
      First   : Positive;
      Minutes : out Integer) return Boolean
   is
      Parsed : constant Posix_Tools.Text.Time_Fields.Parsed_Time_Offset :=
        Posix_Tools.Text.Time_Fields.Parse_ISO_Time_Zone_Offset (Text (First .. Text'Last));
   begin
      Minutes := Parsed.Minutes;
      return Parsed.Valid;
   end Parse_Offset;

   function Parse_Time (Value : String; Hour, Minute, Second : out Natural) return Boolean is
      Parsed : constant Posix_Tools.Text.Time_Fields.Parsed_Time :=
        Posix_Tools.Text.Time_Fields.Parse_HM_Or_HMS (Value);
   begin
      if not Parsed.Valid then
         Hour := 0;
         Minute := 0;
         Second := 0;
         return False;
      else
         Hour := Parsed.Hour;
         Minute := Parsed.Minute;
         Second := Parsed.Second;
         return True;
      end if;
   end Parse_Time;

   function Today_At (Seconds : Duration) return Ada.Calendar.Time is
      Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Year : Ada.Calendar.Year_Number;
      Month : Ada.Calendar.Month_Number;
      Day : Ada.Calendar.Day_Number;
      Ignored : Duration;
   begin
      Ada.Calendar.Split (Now, Year, Month, Day, Ignored);
      return Ada.Calendar.Time_Of (Year, Month, Day, Seconds);
   end Today_At;

   procedure Tokenize (Text : String; Tokens : in out String_Vectors.Vector) is
      Start : Positive := Text'First;
   begin
      while Start <= Text'Last loop
         while Start <= Text'Last
           and then Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (Start))
         loop
            Start := Start + 1;
         end loop;
         exit when Start > Text'Last;
         declare
            Stop : Natural := Start;
         begin
            while Stop <= Text'Last
              and then not Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Text (Stop))
            loop
               Stop := Stop + 1;
            end loop;
            Tokens.Append (Text (Start .. Stop - 1));
            Start := Stop + 1;
         end;
      end loop;
   end Tokenize;

   function Touch_Four_Digits (Text : String; First : Positive) return Natural is
   begin
      return Posix_Tools.Text.Decimal_Parsing.Four_Digit_Value
        (Text (First .. First + 3));
   end Touch_Four_Digits;

   function Touch_Two_Digits (Text : String; First : Positive) return Natural is
   begin
      return Posix_Tools.Text.Decimal_Parsing.Two_Digit_Value
        (Text (First .. First + 1));
   end Touch_Two_Digits;

   function Without_Trailing_Comma (Value : String) return String is
   begin
      if Value'Length > 0 and then Value (Value'Last) = ',' then
         return Value (Value'First .. Value'Last - 1);
      else
         return Value;
      end if;
   end Without_Trailing_Comma;
end Posix_Tools.Commands.Touch_Time_Parsing;
