with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Find_Expressions;

private package Posix_Tools.Commands.Find_Evaluation.Predicates is
   function Glob_Matches (Pattern, Text : String) return Boolean;

   function Type_Matches
     (Path    : String;
      Exists  : Boolean;
      Is_Link : Boolean;
      Kind    : Posix_Tools.Host_Adapters.File_System.File_Kind;
      Filter  : Posix_Tools.Text.Find_Expressions.Find_Type_Filter) return Boolean;

   function Permission_Matches
     (Path  : String;
      Text  : String;
      Valid : in out Boolean) return Boolean;

   function Size_Matches
     (Path  : String;
      Text  : String;
      Valid : in out Boolean) return Boolean;

   function Mtime_Matches
     (Path  : String;
      Text  : String;
      Valid : in out Boolean) return Boolean;

   function Newer_Matches
     (Path      : String;
      Reference : String;
      Valid     : in out Boolean) return Boolean;

   function Ownership_Matches
     (Path  : String;
      Text  : String;
      User  : Boolean;
      Valid : in out Boolean) return Boolean;

   function No_Owner_Matches
     (Path  : String;
      User  : Boolean;
      Valid : in out Boolean) return Boolean;
end Posix_Tools.Commands.Find_Evaluation.Predicates;
