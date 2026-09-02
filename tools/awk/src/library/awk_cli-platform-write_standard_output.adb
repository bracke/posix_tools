separate (Awk_CLI.Platform)
function Write_Standard_Output (Content : String) return Boolean is
begin
   return Standard_Streams.Write_Output (Content);
end Write_Standard_Output;
