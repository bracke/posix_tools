with Ada.Strings.Unbounded;
with Posix_Tools.Arguments;

package Posix_Tools.Host_Adapters.Processes is
   function Run
     (Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean;

   function Run_With_Environment
     (Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Environment : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean;

   function Run_With_Timeout
     (Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Timeout_Ms  : Natural;
      Exit_Status : out Integer;
      Timed_Out   : out Boolean;
      Output      : out Ada.Strings.Unbounded.Unbounded_String;
      Error       : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
end Posix_Tools.Host_Adapters.Processes;
