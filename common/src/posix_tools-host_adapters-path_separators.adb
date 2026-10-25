with Hostkit.Fs;

package body Posix_Tools.Host_Adapters.Path_Separators is
   function Directory_Separator return Character is
   begin
      return Hostkit.Fs.Separator;
   end Directory_Separator;
end Posix_Tools.Host_Adapters.Path_Separators;
