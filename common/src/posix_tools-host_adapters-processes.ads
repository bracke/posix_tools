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
      Timed_Out   : out Boolean) return Boolean;

   function Run_With_Redirected_Output
     (Utility         : String;
      Arguments       : Posix_Tools.Arguments.Vector;
      Output_Path     : String;
      Redirect_Output : Boolean;
      Redirect_Error  : Boolean;
      Exit_Status     : out Integer) return Boolean;
end Posix_Tools.Host_Adapters.Processes;
