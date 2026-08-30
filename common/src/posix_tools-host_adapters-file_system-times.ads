with Ada.Calendar;

package Posix_Tools.Host_Adapters.File_System.Times is
   function Access_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean;
   function Copy_File_Times (Source : String; Target : String) return Boolean;
   function Copy_Modification_Time (Source : String; Target : String) return Boolean;
   function Creation_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean;
   function Current_File_Time return File_Time;
   function File_Access_Time_From_File
     (Path : String;
      Time : out File_Time) return Boolean;
   function File_Time_From_File
     (Path : String;
      Time : out File_Time) return Boolean;
   function File_Time_Of
     (Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Time   : out File_Time) return Boolean;
   function Modification_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean;
   function Set_Access_Time
     (Path : String;
      Time : File_Time) return Boolean;
   function Set_File_Times
     (Path          : String;
      Access_Time   : File_Time;
      Modified_Time : File_Time) return Boolean;
   function Set_Modification_Time
     (Path : String;
      Time : File_Time) return Boolean;
end Posix_Tools.Host_Adapters.File_System.Times;
