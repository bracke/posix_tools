separate (Awk_CLI.Platform)
function Write_Standard_Error (Content : String) return Boolean is
begin
   return Standard_Streams.Write_Error (Content);
end Write_Standard_Error;
