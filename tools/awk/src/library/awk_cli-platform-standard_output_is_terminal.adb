separate (Awk_CLI.Platform)
function Standard_Output_Is_Terminal return Boolean is
begin
   return Host_Metadata.Is_Terminal (1);
end Standard_Output_Is_Terminal;
