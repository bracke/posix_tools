separate (Awk_CLI.Platform)
function Standard_Error_Is_Terminal return Boolean is
begin
   return Host_Metadata.Is_Terminal (2);
end Standard_Error_Is_Terminal;
