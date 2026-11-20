--  Ripgrep-compatible JSON Lines event construction with byte-safe values.
package Posix_Tools.Commands.Rg.Json is
   function Text_Value (Text : String) return String;

   function Begin_Event (Path : String) return String;

   function Submatch
     (Matched         : String;
      First           : Natural;
      Last            : Natural;
      Replacement     : String := "";
      Has_Replacement : Boolean := False) return String;

   function Line_Event
     (Kind            : String;
      Path            : String;
      Line            : String;
      Terminated      : Boolean;
      Line_Number     : Positive;
      Absolute_Offset : Natural;
      Submatches      : String;
      Terminator      : Character := ASCII.LF) return String;

   function End_Event
     (Path             : String;
      Elapsed          : Duration;
      Bytes_Searched   : Natural;
      Bytes_Printed    : Natural;
      Matched_Lines    : Natural;
      Matches          : Natural;
      Search_Had_Match : Boolean;
      Binary_Offset    : Natural := 0;
      Has_Binary_Offset : Boolean := False) return String;

   function Summary_Event
     (Elapsed_Total       : Duration;
      Search_Elapsed      : Duration;
      Searches            : Natural;
      Searches_With_Match : Natural;
      Bytes_Searched      : Natural;
      Bytes_Printed       : Natural;
      Matched_Lines       : Natural;
      Matches             : Natural) return String;
end Posix_Tools.Commands.Rg.Json;
