with Posix_Tools.Version;

package Posix_Tools.Host_Adapters.Executables is
   function Locate (Executable : String) return String;

   function Verify_Identity
     (Executable : String;
      Expected_Version : String := Posix_Tools.Version.Version_String) return String;

   function Verify_Identity_At_Path
     (Executable : String;
      Path       : String;
      Expected_Version : String := Posix_Tools.Version.Version_String) return String;
end Posix_Tools.Host_Adapters.Executables;
