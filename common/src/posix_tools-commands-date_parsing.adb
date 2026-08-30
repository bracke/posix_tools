with Ada.Calendar.Formatting;
with I18N.CLDR_Data;
with Posix_Tools.Host_Adapters.Clock;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.Time_Fields;

package body Posix_Tools.Commands.Date_Parsing is
   use Ada.Strings.Unbounded;

   function All_Digits (Text : String) return Boolean is
   begin
      return Posix_Tools.Text.Decimal_Parsing.Is_Decimal_Text (Text);
   end All_Digits;

   function Two_Digit_Value (Text : String; First : Positive) return Natural is
   begin
      return Posix_Tools.Text.Decimal_Parsing.Two_Digit_Value (Text (First .. First + 1));
   end Two_Digit_Value;

   function Parse_Set_Date_Time
     (Text             : String;
      Current_Year     : Ada.Calendar.Year_Number;
      Time_Zone_Offset : Ada.Calendar.Time_Zones.Time_Offset;
      Parsed           : out Ada.Calendar.Time) return Boolean
   is
      Dot : Natural := 0;
   begin
      if Text = "" then
         return False;
      end if;

      for I in Text'Range loop
         if Text (I) = '.' then
            if Dot /= 0 then
               return False;
            end if;
            Dot := I;
         end if;
      end loop;

      declare
         Main_Last : constant Natural := (if Dot = 0 then Text'Last else Dot - 1);
         Main : constant String := Text (Text'First .. Main_Last);
         Seconds_Text : constant String := (if Dot = 0 then "" else Text (Dot + 1 .. Text'Last));
      begin
         if Main'Length not in 8 | 10 | 12
           or else not All_Digits (Main)
           or else (Seconds_Text /= "" and then (Seconds_Text'Length /= 2 or else not All_Digits (Seconds_Text)))
           or else (Dot /= 0 and then Seconds_Text = "")
         then
            return False;
         end if;

         declare
            Month : constant Natural := Two_Digit_Value (Main, Main'First);
            Day : constant Natural := Two_Digit_Value (Main, Main'First + 2);
            Hour : constant Natural := Two_Digit_Value (Main, Main'First + 4);
            Minute : constant Natural := Two_Digit_Value (Main, Main'First + 6);
            Second : constant Natural :=
              (if Seconds_Text = "" then 0 else Two_Digit_Value (Seconds_Text, Seconds_Text'First));
            Year : Natural := Natural (Current_Year);
         begin
            if Main'Length = 10 then
               declare
                  YY : constant Natural := Two_Digit_Value (Main, Main'First + 8);
               begin
                  Year := (if YY >= 69 then 1900 + YY else 2000 + YY);
               end;
            elsif Main'Length = 12 then
               Year :=
                 Two_Digit_Value (Main, Main'First + 8) * 100
                 + Two_Digit_Value (Main, Main'First + 10);
            end if;

            if Month not in 1 .. 12
              or else Day not in 1 .. 31
              or else Hour > 23
              or else Minute > 59
              or else Second > 60
              or else Year not in Natural (Ada.Calendar.Year_Number'First) .. Natural (Ada.Calendar.Year_Number'Last)
            then
               return False;
            end if;

            Parsed :=
              Ada.Calendar.Formatting.Time_Of
                (Ada.Calendar.Year_Number (Year),
                 Ada.Calendar.Month_Number (Month),
                 Ada.Calendar.Day_Number (Day),
                 Ada.Calendar.Formatting.Hour_Number (Hour),
                 Ada.Calendar.Formatting.Minute_Number (Minute),
                 Ada.Calendar.Formatting.Second_Number ((if Second = 60 then 59 else Second)),
                 Leap_Second => Second = 60,
                 Time_Zone => Time_Zone_Offset);
            return True;
         end;
      end;
   exception
      when Constraint_Error | Ada.Calendar.Time_Error =>
         return False;
   end Parse_Set_Date_Time;

   function Parse_Fixed_TZ
     (Value     : String;
      Offset    : out Ada.Calendar.Time_Zones.Time_Offset;
      Zone_Name : out Unbounded_String) return Boolean
   is
      Name_First  : Positive := Value'First;
      Name_Last   : Natural := 0;
      Offset_First : Natural := Value'First;

      function Is_Zone_Character (Ch : Character) return Boolean is
      begin
         return Posix_Tools.Text.Byte_Classes.Is_ASCII_Alpha (Ch);
      end Is_Zone_Character;

      function Parse_Offset (Text : String; Minutes : out Integer) return Boolean is
         Parsed : constant Posix_Tools.Text.Time_Fields.Parsed_Time_Offset :=
           Posix_Tools.Text.Time_Fields.Parse_POSIX_Time_Zone_Offset (Text);
      begin
         Minutes := Parsed.Minutes;
         return Parsed.Valid;
      end Parse_Offset;

      Minutes : Integer := 0;
      Offset_Last : Natural := 0;
   begin
      if Value'Length < 3 then
         return False;
      end if;

      if Value (Value'First) = '<' then
         for I in Value'First + 1 .. Value'Last loop
            if Value (I) = '>' then
               Name_First := Value'First + 1;
               Name_Last := I - 1;
               Offset_First := I + 1;
               exit;
            end if;
         end loop;
      else
         Name_Last := Value'First - 1;
         while Name_Last < Value'Last and then Is_Zone_Character (Value (Name_Last + 1)) loop
            Name_Last := Name_Last + 1;
         end loop;
         Offset_First := Name_Last + 1;
      end if;

      if Name_Last < Name_First or else Name_Last - Name_First + 1 < 3 then
         return False;
      end if;

      if Offset_First <= Value'Last then
         Offset_Last := Offset_First - 1;
         for J in Offset_First .. Value'Last loop
            exit when Value (J) not in '+' | '-' | ':' | '0' .. '9';
            Offset_Last := J;
         end loop;

         if Offset_Last < Offset_First
           or else not Parse_Offset (Value (Offset_First .. Offset_Last), Minutes)
         then
            return False;
         end if;
      else
         if not Parse_Offset ("", Minutes) then
            return False;
         end if;
      end if;

      Offset := Ada.Calendar.Time_Zones.Time_Offset (Minutes);
      Zone_Name :=
        To_Unbounded_String
          ((if Minutes = 0
            and then Value (Name_First .. Name_Last) in "UTC" | "GMT"
            then "UTC"
            else Value (Name_First .. Name_Last)));
      return True;
   exception
      when Constraint_Error =>
         return False;
   end Parse_Fixed_TZ;

   function Parse_I18N_TZ
     (Value          : String;
      Reference_Time : Ada.Calendar.Time;
      Locale         : String;
      Offset         : out Ada.Calendar.Time_Zones.Time_Offset;
      Zone_Name      : out Unbounded_String) return Boolean
   is
      Canonical : constant String := I18N.CLDR_Data.Canonical_Time_Zone (Value);
      Year : Ada.Calendar.Year_Number;
      Month : Ada.Calendar.Month_Number;
      Day : Ada.Calendar.Day_Number;
      Hour : Ada.Calendar.Formatting.Hour_Number;
      Minute : Ada.Calendar.Formatting.Minute_Number;
      Second : Ada.Calendar.Formatting.Second_Number;
      Sub_Second : Ada.Calendar.Formatting.Second_Duration;
      Valid : Boolean;
      Offset_Seconds : Integer;
      Base_Valid : Boolean;
      Base_Minutes : Integer;
      Family : Unbounded_String;
      Short_Name : Unbounded_String;
   begin
      Ada.Calendar.Formatting.Split
        (Reference_Time, Year, Month, Day, Hour, Minute, Second, Sub_Second, Time_Zone => 0);

      Offset_Seconds :=
        I18N.CLDR_Data.Time_Zone_Offset_Seconds_At_UTC
          (Canonical,
           Natural (Year),
           Natural (Month),
           Natural (Day),
           Natural (Hour),
           Natural (Minute),
           Natural (Second),
           Valid);

      if not Valid or else Offset_Seconds mod 60 /= 0 then
         return False;
      end if;

      Offset := Ada.Calendar.Time_Zones.Time_Offset (Offset_Seconds / 60);
      Base_Minutes := I18N.CLDR_Data.Time_Zone_Base_Offset_Minutes (Canonical, Base_Valid);
      Family := To_Unbounded_String (I18N.CLDR_Data.Time_Zone_DST_Family (Canonical));
      if To_String (Family) /= "" then
         Short_Name :=
           To_Unbounded_String
             (I18N.CLDR_Data.Time_Zone_Short_Name
                (Locale,
                 To_String (Family),
                 Base_Valid and then Offset_Seconds /= Base_Minutes * 60));
      end if;

      Zone_Name :=
        (if To_String (Short_Name) /= ""
         then Short_Name
         elsif Canonical in "UTC" | "Etc/UTC" | "Etc/GMT" | "Z"
         then To_Unbounded_String ("UTC")
         else To_Unbounded_String (Canonical));
      return True;
   exception
      when Constraint_Error | Ada.Calendar.Time_Error =>
         return False;
   end Parse_I18N_TZ;

   function Resolve_Time_Zone
     (Value          : String;
      Reference_Time : Ada.Calendar.Time;
      Locale         : String;
      Offset         : out Ada.Calendar.Time_Zones.Time_Offset;
      Zone_Name      : out Unbounded_String) return Boolean
   is
   begin
      return Parse_Fixed_TZ (Value, Offset, Zone_Name)
        or else Posix_Tools.Host_Adapters.Clock.Resolve_Time_Zone
          (Value, Reference_Time, Offset, Zone_Name)
        or else Parse_I18N_TZ
          (Value, Reference_Time, Locale, Offset, Zone_Name);
   end Resolve_Time_Zone;
end Posix_Tools.Commands.Date_Parsing;
