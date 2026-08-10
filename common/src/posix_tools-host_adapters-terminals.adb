with Hostkit.Host;

package body Posix_Tools.Host_Adapters.Terminals is
   function Standard_Output_Is_Terminal return Boolean is
   begin
      return Hostkit.Host.Is_Terminal (Hostkit.Host.Standard_Output);
   exception
      when others =>
         return False;
   end Standard_Output_Is_Terminal;
end Posix_Tools.Host_Adapters.Terminals;
