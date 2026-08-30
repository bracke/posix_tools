with Posix_Tools.Commands.Touch_Time_Parsing;

package body Posix_Tools.Commands.Touch_Times is
   function Parse_Date_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
   begin
      return Posix_Tools.Commands.Touch_Time_Parsing.Parse_Date_Time (Text, Parsed);
   end Parse_Date_Time;

   function Parse_Explicit_Time (Text : String; Parsed : out FS.File_Time) return Boolean is
   begin
      return Posix_Tools.Commands.Touch_Time_Parsing.Parse_Explicit_Time (Text, Parsed);
   end Parse_Explicit_Time;
end Posix_Tools.Commands.Touch_Times;
