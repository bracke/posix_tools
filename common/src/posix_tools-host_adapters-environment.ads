with Posix_Tools.Arguments;

package Posix_Tools.Host_Adapters.Environment is
   function Pairs return Posix_Tools.Arguments.Vector;
   function Value (Name : String) return String;
end Posix_Tools.Host_Adapters.Environment;
