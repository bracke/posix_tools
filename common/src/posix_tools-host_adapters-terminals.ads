package Posix_Tools.Host_Adapters.Terminals is
   function Standard_Input_Is_Terminal return Boolean;
   function Standard_Input_Terminal_Name return String;
   function Standard_Output_Is_Terminal return Boolean;
   function Standard_Error_Is_Terminal return Boolean;
end Posix_Tools.Host_Adapters.Terminals;
