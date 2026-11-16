with Posix_Tools.Accounts;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Find_Expressions;

--  The predicates that read a file's status take Own: True examines a
--  symbolic link itself (lstat), False the file a pathname resolves to.
private package Posix_Tools.Commands.Find_Evaluation.Predicates is
   function Glob_Matches (Pattern, Text : String) return Boolean;

   function Type_Matches
     (Path    : String;
      Exists  : Boolean;
      Is_Link : Boolean;
      Kind    : Posix_Tools.Host_Adapters.File_System.File_Kind;
      Filter  : Posix_Tools.Text.Find_Expressions.Find_Type_Filter) return Boolean;

   function Permission_Matches
     (Status    : Posix_Tools.Host_Adapters.File_System.Entry_Status;
      Expected  : Natural;
      Match_All : Boolean) return Boolean;

   function Size_Matches
     (Status   : Posix_Tools.Host_Adapters.File_System.Entry_Status;
      Own      : Boolean;
      Exists   : Boolean;
      Kind     : Posix_Tools.Host_Adapters.File_System.File_Kind;
      Count    : Long_Long_Integer;
      Relation : Posix_Tools.Text.Find_Expressions.Count_Relation;
      Bytes    : Boolean) return Boolean;

   --  Whether Path was last modified as long before Now as -mtime Text asks.
   function Mtime_Matches
     (Status   : Posix_Tools.Host_Adapters.File_System.Entry_Status;
      Exists   : Boolean;
      Count    : Long_Long_Integer;
      Relation : Posix_Tools.Text.Find_Expressions.Count_Relation;
      Now      : Ada.Calendar.Time;
      Valid    : in out Boolean) return Boolean;

   function Newer_Matches
     (Status          : Posix_Tools.Host_Adapters.File_System.Entry_Status;
      Exists          : Boolean;
      Reference_Time  : Ada.Calendar.Time;
      Reference_Valid : Boolean;
      Valid           : in out Boolean) return Boolean;

   function Ownership_Matches
     (Status         : Posix_Tools.Host_Adapters.File_System.Entry_Status;
      Expected       : Posix_Tools.Accounts.Id;
      Expected_Found : Boolean;
      User           : Boolean;
      Valid          : in out Boolean) return Boolean;

   function No_Owner_Matches
     (Status : Posix_Tools.Host_Adapters.File_System.Entry_Status;
      User  : Boolean;
      Valid : in out Boolean) return Boolean;
end Posix_Tools.Commands.Find_Evaluation.Predicates;
