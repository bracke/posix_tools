with Ada.Environment_Variables;

package body Posix_Tools.Host_Adapters.Environment is
   function Value (Name : String) return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      else
         return "";
      end if;
   end Value;
end Posix_Tools.Host_Adapters.Environment;
