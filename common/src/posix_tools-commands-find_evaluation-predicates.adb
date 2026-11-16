with Ada.Calendar;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Glob;
with Posix_Tools.Unix_Time;

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

   --  Status's last modification.
   function Modified_At
     (Status : FS.Entry_Status;
      Time : out Ada.Calendar.Time) return Boolean;

   function Modified_At
     (Status : FS.Entry_Status;
      Time : out Ada.Calendar.Time) return Boolean
   is
   begin
      Time := Posix_Tools.Unix_Time.Epoch;
      if not Status.Available then
         return False;
      end if;
      Time := Posix_Tools.Unix_Time.Time_Of (Status.Modified_Seconds);
      return True;
   exception
      when Constraint_Error | Ada.Calendar.Time_Error =>
         return False;
   end Modified_At;

   function Glob_Matches (Pattern, Text : String) return Boolean is (Posix_Tools.Text.Glob.Matches (Pattern, Text));

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
                 False,
                 False,
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
     (Status    : FS.Entry_Status;
      Expected  : Natural;
      Match_All : Boolean) return Boolean
   is
      Available : constant Boolean := Status.Available;
      Actual    : constant Natural := Status.Mode mod 8#10000#;
   begin
      if not FS.Permissions_Supported or else not Available then
         return False;
      else
         return
           Posix_Tools.Text.File_Modes.Permission_Matches
             (Actual, Expected, Match_All);
      end if;
   end Permission_Matches;

   function Size_Matches
     (Status   : FS.Entry_Status;
      Own      : Boolean;
      Exists   : Boolean;
      Kind     : FS.File_Kind;
      Count    : Long_Long_Integer;
      Relation : Find_Count_Relation;
      Bytes    : Boolean) return Boolean
   is
      Units    : Long_Long_Integer;
   begin
      if not Exists or else (not Own and then Kind = FS.Directory) then
         return False;
      end if;

      if not Status.Available then
         return False;
      end if;

      Units := (if Bytes then Status.Size else (Status.Size + 511) / 512);

      return
        Posix_Tools.Text.Find_Expressions.Count_Matches
          (Units, Count, Relation);
   end Size_Matches;

   function Mtime_Matches
     (Status   : FS.Entry_Status;
      Exists   : Boolean;
      Count    : Long_Long_Integer;
      Relation : Find_Count_Relation;
      Now      : Ada.Calendar.Time;
      Valid    : in out Boolean) return Boolean
   is
      Seconds_Per_Day : constant Duration := 86_400.0;
      function Threshold (Value : Long_Long_Integer; Ok : in out Boolean) return Duration is
      begin
         if Value < 0 or else Value > Long_Long_Integer (Duration'Last / Seconds_Per_Day) then
            Ok := False;
            return 0.0;
         end if;
         return Duration (Value) * Seconds_Per_Day;
      end Threshold;
   begin
      if not Exists then
         Valid := False;
         return False;
      end if;

      declare
         Path_Time : Ada.Calendar.Time;
         Ok  : Boolean := True;
      begin
         if not Modified_At (Status, Path_Time) then
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
     (Status          : FS.Entry_Status;
      Exists          : Boolean;
      Reference_Time  : Ada.Calendar.Time;
      Reference_Valid : Boolean;
      Valid           : in out Boolean) return Boolean
   is
   begin
      if not Reference_Valid or else not Exists then
         Valid := False;
         return False;
      end if;
      declare
         Path_Time : Ada.Calendar.Time;
      begin
         if not Modified_At (Status, Path_Time) then
            Valid := False;
            return False;
         end if;
         return Path_Time > Reference_Time;
      end;
   exception
      when others =>
         --  intentional terminal exception barrier
         Valid := False;
         return False;
   end Newer_Matches;

   function Ownership_Matches
     (Status         : FS.Entry_Status;
      Expected       : Posix_Tools.Accounts.Id;
      Expected_Found : Boolean;
      User           : Boolean;
      Valid          : in out Boolean) return Boolean
   is
   begin
      if not Expected_Found or else not FS.Ownership_Supported then
         return False;
      end if;

      return
        Posix_Tools.Text.Find_Expressions.Ownership_Matches
          (Status.Available, User, Status.User, Status.Group, Expected);
   exception
      when others =>
         --  intentional terminal exception barrier
         Valid := False;
         return False;
   end Ownership_Matches;

   function No_Owner_Matches
     (Status : FS.Entry_Status;
      User  : Boolean;
      Valid : in out Boolean) return Boolean
   is
   begin
      if not FS.Ownership_Supported then
         return False;
      end if;

      return
        Posix_Tools.Text.Find_Expressions.Missing_Owner_Name_Matches
          (Status.Available,
           (if User
            then FS.User_Name_For_Id (Status.User)
            else FS.Group_Name_For_Id (Status.Group)));
   exception
      when others =>
         --  intentional terminal exception barrier
         Valid := False;
         return False;
   end No_Owner_Matches;
end Posix_Tools.Commands.Find_Evaluation.Predicates;
