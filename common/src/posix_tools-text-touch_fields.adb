with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;

package body Posix_Tools.Text.Touch_Fields
  with SPARK_Mode => On
is
   function Lowercase (Value : Character) return Character;

   function Invalid_Normalized_Date_Time return Normalized_Date_Time;

   function Same_Case_Insensitive (Left, Right : String) return Boolean;

   function Invalid_Normalized_Date_Time return Normalized_Date_Time is
   begin
      return (Valid => False, Changed => False, Length => 0, Text => [others => ' ']);
   end Invalid_Normalized_Date_Time;

   function Is_Ago (Name : String) return Boolean is
   begin
      return Same_Case_Insensitive (Name, "ago");
   end Is_Ago;

   function Lowercase (Value : Character) return Character is
   begin
      if Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper (Value) then
         return Posix_Tools.Text.Byte_Classes.To_ASCII_Lower (Value);
      else
         return Value;
      end if;
   end Lowercase;

   function Month_Number (Name : String) return Month_Index is
   begin
      if Same_Case_Insensitive (Name, "jan")
        or else Same_Case_Insensitive (Name, "january")
      then
         return 1;
      elsif Same_Case_Insensitive (Name, "feb")
        or else Same_Case_Insensitive (Name, "february")
      then
         return 2;
      elsif Same_Case_Insensitive (Name, "mar")
        or else Same_Case_Insensitive (Name, "march")
      then
         return 3;
      elsif Same_Case_Insensitive (Name, "apr")
        or else Same_Case_Insensitive (Name, "april")
      then
         return 4;
      elsif Same_Case_Insensitive (Name, "may") then
         return 5;
      elsif Same_Case_Insensitive (Name, "jun")
        or else Same_Case_Insensitive (Name, "june")
      then
         return 6;
      elsif Same_Case_Insensitive (Name, "jul")
        or else Same_Case_Insensitive (Name, "july")
      then
         return 7;
      elsif Same_Case_Insensitive (Name, "aug")
        or else Same_Case_Insensitive (Name, "august")
      then
         return 8;
      elsif Same_Case_Insensitive (Name, "sep")
        or else Same_Case_Insensitive (Name, "sept")
        or else Same_Case_Insensitive (Name, "september")
      then
         return 9;
      elsif Same_Case_Insensitive (Name, "oct")
        or else Same_Case_Insensitive (Name, "october")
      then
         return 10;
      elsif Same_Case_Insensitive (Name, "nov")
        or else Same_Case_Insensitive (Name, "november")
      then
         return 11;
      elsif Same_Case_Insensitive (Name, "dec")
        or else Same_Case_Insensitive (Name, "december")
      then
         return 12;
      else
         return 0;
      end if;
   end Month_Number;

   function Normalize_ISO_Date_Time (Text : String) return Normalized_Date_Time is
      Result : Normalized_Date_Time :=
        (Valid => True, Changed => False, Length => 0, Text => [others => ' ']);
      I      : Positive := Text'First;

      procedure Append_Normalized (Ch : Character; Ok : out Boolean);

      procedure Append_Normalized (Ch : Character; Ok : out Boolean) is
      begin
         if Result.Length = Normalized_Date_Time_Length'Last then
            Ok := False;
         else
            Result.Length := Result.Length + 1;
            Result.Text (Result.Length) := Ch;
            Ok := True;
         end if;
      end Append_Normalized;
   begin
      if Text = "" then
         return Invalid_Normalized_Date_Time;
      end if;

      while I <= Text'Last loop
         pragma Loop_Invariant (Result.Valid);
         pragma Loop_Invariant (I in Text'First .. Text'Last + 1);
         pragma Loop_Variant (Decreases => Text'Last + 1 - I);

         declare
            Old_I    : constant Positive := I;
            Appended : Boolean;
         begin
            if (I = Text'First + 4 or else I = Text'First + 7) and then Text (I) = '/' then
               Append_Normalized ('-', Appended);
               if not Appended then
                  return Invalid_Normalized_Date_Time;
               end if;
               Result.Changed := True;
               I := I + 1;
            elsif I = Text'First + 10 and then Text (I) = 't' then
               Append_Normalized ('T', Appended);
               if not Appended then
                  return Invalid_Normalized_Date_Time;
               end if;
               Result.Changed := True;
               I := I + 1;
            elsif I = Text'First + 19 and then Text (I) = '.' then
               Result.Changed := True;
               I := I + 1;
               if I > Text'Last
                 or else not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I))
               then
                  return Invalid_Normalized_Date_Time;
               end if;
               pragma Assert (I > Old_I);
               while I <= Text'Last and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I)) loop
                  pragma Loop_Invariant (I in Text'First .. Text'Last);
                  pragma Loop_Invariant (I > Old_I);
                  pragma Loop_Variant (Increases => I);
                  I := I + 1;
               end loop;
            else
               Append_Normalized (Text (I), Appended);
               if not Appended then
                  return Invalid_Normalized_Date_Time;
               end if;
               I := I + 1;
            end if;

            pragma Assert (I > Old_I);
         end;
      end loop;

      if Result.Changed then
         return Result;
      else
         return Invalid_Normalized_Date_Time;
      end if;
   end Normalize_ISO_Date_Time;

   function Relative_Direction_For (Name : String) return Relative_Direction is
   begin
      if Same_Case_Insensitive (Name, "next") then
         return 1;
      elsif Same_Case_Insensitive (Name, "last") then
         return -1;
      else
         return 0;
      end if;
   end Relative_Direction_For;

   function Same_Case_Insensitive (Left, Right : String) return Boolean is
      Left_Index : Integer := Left'First;
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;

      for Right_Index in Right'Range loop
         pragma Loop_Invariant (Left_Index in Left'Range);
         pragma Loop_Invariant (Left_Index - Left'First = Right_Index - Right'First);

         if Lowercase (Left (Left_Index)) /= Lowercase (Right (Right_Index)) then
            return False;
         end if;

         if Right_Index < Right'Last then
            Left_Index := Left_Index + 1;
         end if;
      end loop;

      return True;
   end Same_Case_Insensitive;

   function Unit_Seconds (Name : String) return Unit_Seconds_Value is
   begin
      if Same_Case_Insensitive (Name, "second")
        or else Same_Case_Insensitive (Name, "seconds")
        or else Same_Case_Insensitive (Name, "sec")
        or else Same_Case_Insensitive (Name, "secs")
      then
         return 1;
      elsif Same_Case_Insensitive (Name, "minute")
        or else Same_Case_Insensitive (Name, "minutes")
        or else Same_Case_Insensitive (Name, "min")
        or else Same_Case_Insensitive (Name, "mins")
      then
         return 60;
      elsif Same_Case_Insensitive (Name, "hour")
        or else Same_Case_Insensitive (Name, "hours")
      then
         return 3_600;
      elsif Same_Case_Insensitive (Name, "day")
        or else Same_Case_Insensitive (Name, "days")
      then
         return 86_400;
      elsif Same_Case_Insensitive (Name, "week")
        or else Same_Case_Insensitive (Name, "weeks")
      then
         return 604_800;
      else
         return 0;
      end if;
   end Unit_Seconds;

   function Valid_POSIX_Timestamp (Text : String) return Boolean is
      Dot : Natural := 0;
   begin
      if Text = "" then
         return False;
      end if;

      for I in Text'Range loop
         pragma Loop_Invariant (Dot = 0 or else Dot in Text'Range);

         if Text (I) = '.' then
            if Dot /= 0 then
               return False;
            end if;
            Dot := I;
         elsif not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit (Text (I)) then
            return False;
         end if;
      end loop;

      declare
         Main_Last   : constant Natural := (if Dot = 0 then Text'Last else Dot - 1);
         Main_Length : constant Natural := Main_Last - Text'First + 1;
      begin
         if Dot /= 0
           and then
             (Dot = Text'Last
              or else Text'Last - Dot /= 2
              or else not Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range
                (Text (Dot + 1 .. Text'Last), 0, 61))
         then
            return False;
         elsif Main_Length not in 8 | 10 | 12 | 14 then
            return False;
         end if;

         return Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range
             (Text (Main_Last - 7 .. Main_Last - 6), 1, 12)
           and then Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range
             (Text (Main_Last - 5 .. Main_Last - 4), 1, 31)
           and then Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range
             (Text (Main_Last - 3 .. Main_Last - 2), 0, 23)
           and then Posix_Tools.Text.Decimal_Parsing.Decimal_In_Range
             (Text (Main_Last - 1 .. Main_Last), 0, 59);
      end;
   end Valid_POSIX_Timestamp;

   function Weekday_Number (Name : String) return Weekday_Index is
   begin
      if Same_Case_Insensitive (Name, "mon")
        or else Same_Case_Insensitive (Name, "monday")
      then
         return 1;
      elsif Same_Case_Insensitive (Name, "tue")
        or else Same_Case_Insensitive (Name, "tues")
        or else Same_Case_Insensitive (Name, "tuesday")
      then
         return 2;
      elsif Same_Case_Insensitive (Name, "wed")
        or else Same_Case_Insensitive (Name, "wednesday")
      then
         return 3;
      elsif Same_Case_Insensitive (Name, "thu")
        or else Same_Case_Insensitive (Name, "thur")
        or else Same_Case_Insensitive (Name, "thurs")
        or else Same_Case_Insensitive (Name, "thursday")
      then
         return 4;
      elsif Same_Case_Insensitive (Name, "fri")
        or else Same_Case_Insensitive (Name, "friday")
      then
         return 5;
      elsif Same_Case_Insensitive (Name, "sat")
        or else Same_Case_Insensitive (Name, "saturday")
      then
         return 6;
      elsif Same_Case_Insensitive (Name, "sun")
        or else Same_Case_Insensitive (Name, "sunday")
      then
         return 7;
      else
         return 0;
      end if;
   end Weekday_Number;
end Posix_Tools.Text.Touch_Fields;
