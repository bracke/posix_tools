with Hostkit.Descriptors;

package body Posix_Tools.Host_Adapters.Terminals is
   function Standard_Input_Is_Terminal return Boolean is
   begin
      return Hostkit.Descriptors.Is_Terminal (Hostkit.Descriptors.Standard_Input);
   exception
      when others =>
         return False;
   end Standard_Input_Is_Terminal;

   function Standard_Output_Is_Terminal return Boolean is
   begin
      return Hostkit.Descriptors.Is_Terminal (Hostkit.Descriptors.Standard_Output);
   exception
      when others =>
         return False;
   end Standard_Output_Is_Terminal;

   function Standard_Error_Is_Terminal return Boolean is
   begin
      return Hostkit.Descriptors.Is_Terminal (Hostkit.Descriptors.Standard_Error);
   exception
      when others =>
         return False;
   end Standard_Error_Is_Terminal;
end Posix_Tools.Host_Adapters.Terminals;
