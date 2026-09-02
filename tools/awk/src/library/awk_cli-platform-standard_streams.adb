separate (Awk_CLI.Platform)
package body Standard_Streams is
   function Write_Output (Content : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.Streams.Write_Standard_Output (Content);
   end Write_Output;

   function Write_Error (Content : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.Streams.Write_Standard_Error (Content);
   end Write_Error;
end Standard_Streams;
