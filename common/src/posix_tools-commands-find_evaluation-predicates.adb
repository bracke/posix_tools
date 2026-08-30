with Ada.Calendar;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Glob_Fields;

package body Posix_Tools.Commands.Find_Evaluation.Predicates is
   use type Ada.Calendar.Time;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   subtype Find_Count_Relation is Posix_Tools.Text.Find_Expressions.Count_Relation;
   Exact_Count : constant Find_Count_Relation :=
     Posix_Tools.Text.Find_Expressions.Exact_Count;
   Greater_Than_Count : constant Find_Count_Relation :=
     Posix_Tools.Text.Find_Expressions.Greater_Than_Count;
   Less_Than_Count : constant Find_Count_Relation :=
     Posix_Tools.Text.Find_Expressions.Less_Than_Count;

   function Parse_Permission_Mode
     (Text : String;
      Mode : out Natural;
      Match_All : out Boolean) return Boolean
   is
      Parsed : constant Posix_Tools.Text.File_Modes.Parsed_Permission_Mode :=
        Posix_Tools.Text.File_Modes.Parse_Find_Permission_Mode (Text);
   begin
      Mode := Parsed.Mode;
      Match_All := Parsed.Match_All;
      case Parsed.Status is
         when Posix_Tools.Text.File_Modes.Invalid_Permission_Mode =>
            return False;
         when Posix_Tools.Text.File_Modes.Octal_Permission_Mode
           | Posix_Tools.Text.File_Modes.Symbolic_Permission_Mode =>
            return True;
      end case;
   end Parse_Permission_Mode;

   function Parse_Find_Count
     (Text     : String;
      Count    : out Long_Long_Integer;
      Relation : out Find_Count_Relation;
      Bytes    : out Boolean) return Boolean
   is
      Parsed : constant Posix_Tools.Text.Find_Expressions.Parsed_Find_Count :=
        Posix_Tools.Text.Find_Expressions.Parse_Find_Count (Text);
   begin
      Count := Parsed.Count;
      Relation := Parsed.Relation;
      Bytes := Parsed.Bytes;
      return Parsed.Valid;
   end Parse_Find_Count;

   function Glob_Matches (Pattern, Text : String) return Boolean is
      function Match_From (P, T : Natural) return Boolean is
      begin
         if P > Pattern'Last then
            return T > Text'Last;
         elsif Pattern (P) = '*' then
            for Next in T .. Text'Last + 1 loop
               if Match_From (P + 1, Next) then
                  return True;
               end if;
            end loop;
            return False;
         elsif Pattern (P) = '?' then
            return T <= Text'Last and then Match_From (P + 1, T + 1);
         elsif Pattern (P) = '[' then
            declare
               Closing : constant Natural :=
                 (if P < Pattern'Last then
                    Posix_Tools.Text.Glob_Fields.Closing_Bracket_From (Pattern, P)
                  else
                    0);
            begin
               if Closing = 0 then
                  return T <= Text'Last
                    and then Pattern (P) = Text (T)
                    and then Match_From (P + 1, T + 1);
               elsif T > Text'Last then
                  return False;
               else
                  return Posix_Tools.Text.Glob_Fields.Bracket_Class_Matches
                      (Pattern, P, Closing, Text (T))
                    and then Match_From (Closing + 1, T + 1);
               end if;
            end;
         elsif T <= Text'Last and then Pattern (P) = Text (T) then
            return Match_From (P + 1, T + 1);
         else
            return False;
         end if;
      end Match_From;
   begin
      return Match_From (Pattern'First, Text'First);
   end Glob_Matches;

   function Type_Matches
     (Path    : String;
      Exists  : Boolean;
      Is_Link : Boolean;
      Kind    : FS.File_Kind;
      Filter  : Posix_Tools.Text.Find_Expressions.Find_Type_Filter) return Boolean
   is
      use type Posix_Tools.Text.Find_Expressions.Find_Type_Filter;

      No_Special_File : constant Posix_Tools.Text.Find_Expressions.Find_Special_File_Class :=
        Posix_Tools.Text.Find_Expressions.No_Special_File;
   begin
      if Filter in Posix_Tools.Text.Find_Expressions.Block_Device_Type
                | Posix_Tools.Text.Find_Expressions.Character_Device_Type
                | Posix_Tools.Text.Find_Expressions.FIFO_Type
                | Posix_Tools.Text.Find_Expressions.Socket_Type
        and then Exists
        and then Kind = FS.Special_File
      then
         declare
            Info : constant FS.Special_File_Info := FS.Special_File_Info_Of (Path);
            Special_Class : Posix_Tools.Text.Find_Expressions.Find_Special_File_Class :=
              No_Special_File;
         begin
            if Info.Available then
               Special_Class :=
                 (case Info.Kind is
                    when FS.Block_Device =>
                      Posix_Tools.Text.Find_Expressions.Block_Device_File,
                    when FS.Character_Device =>
                      Posix_Tools.Text.Find_Expressions.Character_Device_File,
                    when FS.FIFO =>
                      Posix_Tools.Text.Find_Expressions.FIFO_File,
                    when FS.Socket =>
                      Posix_Tools.Text.Find_Expressions.Socket_File,
                    when FS.Not_Special | FS.Other_Special =>
                      No_Special_File);
            end if;

            return
              Posix_Tools.Text.Find_Expressions.Type_Matches
                (Filter,
                 Exists,
                 Kind = FS.Directory,
                 Kind = FS.Ordinary_File,
                 Is_Link,
                 Info.Available,
                 Special_Class);
         end;
      else
         return
           Posix_Tools.Text.Find_Expressions.Type_Matches
             (Filter,
              Exists,
              Kind = FS.Directory,
              Kind = FS.Ordinary_File,
              Is_Link,
              False,
              No_Special_File);
      end if;
   end Type_Matches;

   function Permission_Matches
     (Path  : String;
      Text  : String;
      Valid : in out Boolean) return Boolean
   is
      Available : Boolean;
      Actual    : constant Natural := FS.File_Permission_Bits (Path, Available) mod 8#10000#;
      Expected  : Natural;
      Match_All : Boolean;
   begin
      if not Parse_Permission_Mode (Text, Expected, Match_All) then
         Valid := False;
         return False;
      elsif not FS.Permissions_Supported or else not Available then
         return False;
      else
         return
           Posix_Tools.Text.File_Modes.Permission_Matches
             (Actual, Expected, Match_All);
      end if;
   end Permission_Matches;

   function Size_Matches
     (Path  : String;
      Text  : String;
      Valid : in out Boolean) return Boolean
   is
      Exists   : constant Boolean := FS.Exists (Path);
      Kind     : constant FS.File_Kind := FS.Kind (Path);
      Count    : Long_Long_Integer;
      Relation : Find_Count_Relation;
      Bytes    : Boolean;
      Units    : Long_Long_Integer;
   begin
      if not Exists or else Kind = FS.Directory then
         return False;
      elsif not Parse_Find_Count (Text, Count, Relation, Bytes) then
         Valid := False;
         return False;
      end if;

      declare
         Raw_Size : constant Long_Long_Integer := FS.Size (Path);
      begin
         Units := (if Bytes then Raw_Size else (Raw_Size + 511) / 512);
      end;

      return
        Posix_Tools.Text.Find_Expressions.Count_Matches
          (Units, Count, Relation);
   end Size_Matches;

   function Mtime_Matches
     (Path  : String;
      Text  : String;
      Valid : in out Boolean) return Boolean
   is
      Seconds_Per_Day : constant Duration := 86_400.0;
      Count           : Long_Long_Integer;
      Relation        : Find_Count_Relation;
      Bytes           : Boolean;

      function Threshold (Value : Long_Long_Integer; Ok : in out Boolean) return Duration is
      begin
         if Value < 0 or else Value > Long_Long_Integer (Duration'Last / Seconds_Per_Day) then
            Ok := False;
            return 0.0;
         end if;
         return Duration (Value) * Seconds_Per_Day;
      end Threshold;
   begin
      if not FS.Exists (Path) or else not Parse_Find_Count (Text, Count, Relation, Bytes) or else Bytes then
         Valid := False;
         return False;
      end if;

      declare
         Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
         Path_Time : Ada.Calendar.Time;
         Ok  : Boolean := True;
      begin
         if not FS.Modification_Time (Path, Path_Time) then
            Valid := False;
            return False;
         end if;

         case Relation is
            when Exact_Count =>
               if Count = Long_Long_Integer'Last then
                  Valid := False;
                  return False;
               end if;
               declare
                  Low  : constant Duration := Threshold (Count, Ok);
                  High : constant Duration := Threshold (Count + 1, Ok);
               begin
                  Valid := Valid and then Ok;
                  return
                    Ok
                    and then Posix_Tools.Text.Find_Expressions.Age_Matches
                      (Now - Path_Time, Low, High, Relation);
               end;
            when Greater_Than_Count =>
               if Count = Long_Long_Integer'Last then
                  return False;
               end if;
               declare
                  Low : constant Duration := Threshold (Count + 1, Ok);
               begin
                  Valid := Valid and then Ok;
                  return
                    Ok
                    and then Posix_Tools.Text.Find_Expressions.Age_Matches
                      (Now - Path_Time, Low, 0.0, Relation);
               end;
            when Less_Than_Count =>
               declare
                  High : constant Duration := Threshold (Count, Ok);
               begin
                  Valid := Valid and then Ok;
                  return
                    Ok
                    and then Posix_Tools.Text.Find_Expressions.Age_Matches
                      (Now - Path_Time, 0.0, High, Relation);
               end;
         end case;
      end;
   end Mtime_Matches;

   function Newer_Matches
     (Path      : String;
      Reference : String;
      Valid     : in out Boolean) return Boolean
   is
   begin
      if not FS.Exists (Path) or else not FS.Exists (Reference) then
         Valid := False;
         return False;
      end if;
      declare
         Path_Time      : Ada.Calendar.Time;
         Reference_Time : Ada.Calendar.Time;
      begin
         if not FS.Modification_Time (Path, Path_Time)
           or else not FS.Modification_Time (Reference, Reference_Time)
         then
            Valid := False;
            return False;
         end if;
         return Path_Time > Reference_Time;
      end;
   exception
      when others =>
         Valid := False;
         return False;
   end Newer_Matches;

   function Ownership_Matches
     (Path  : String;
      Text  : String;
      User  : Boolean;
      Valid : in out Boolean) return Boolean
   is
      Actual_User  : Natural;
      Actual_Group : Natural;
      Available    : Boolean;
      Expected     : Natural := 0;
      Found        : Boolean := False;
   begin
      if User then
         Found := Posix_Tools.Commands.Helpers.Resolve_User_Id (Text, Expected);
      else
         Found := Posix_Tools.Commands.Helpers.Resolve_Group_Id (Text, Expected);
      end if;

      if not Found or else not FS.Ownership_Supported then
         return False;
      end if;

      FS.File_Ownership (Path, Actual_User, Actual_Group, Available);
      return
        Posix_Tools.Text.Find_Expressions.Ownership_Matches
          (Available, User, Actual_User, Actual_Group, Expected);
   exception
      when others =>
         Valid := False;
         return False;
   end Ownership_Matches;

   function No_Owner_Matches
     (Path  : String;
      User  : Boolean;
      Valid : in out Boolean) return Boolean
   is
      Actual_User  : Natural;
      Actual_Group : Natural;
      Available    : Boolean;
   begin
      if not FS.Ownership_Supported then
         return False;
      end if;

      FS.File_Ownership (Path, Actual_User, Actual_Group, Available);
      return
        Posix_Tools.Text.Find_Expressions.Missing_Owner_Name_Matches
          (Available,
           (if User
            then FS.User_Name_For_Id (Actual_User)
            else FS.Group_Name_For_Id (Actual_Group)));
   exception
      when others =>
         Valid := False;
         return False;
   end No_Owner_Matches;
end Posix_Tools.Commands.Find_Evaluation.Predicates;
