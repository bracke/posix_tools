with Posix_Tools.Host_Adapters.File_System;

package Posix_Tools.Commands.Touch_Time_Parsing is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   function Parse_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean;

   function Parse_Explicit_Time (Text : String; Parsed : out FS.File_Time) return Boolean;
end Posix_Tools.Commands.Touch_Time_Parsing;
