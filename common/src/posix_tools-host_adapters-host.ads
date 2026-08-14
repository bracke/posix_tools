package Posix_Tools.Host_Adapters.Host is
   type Host_Kind is (Linux, MacOS, Windows, Unsupported);

   function Current return Host_Kind;
   function Current_User_Id (User_Id : out Natural) return Boolean;
   type Group_Id_List is array (Positive range <>) of Natural;
   function Current_Group_Id (Group_Id : out Natural) return Boolean;
   function Current_Supplementary_Group_Ids
     (Groups : out Group_Id_List;
      Last   : out Natural)
      return Boolean;
   function Native_Locale return String;
   function Own_Process_Id return Integer;
   function System_Name return String;
   function Node_Name return String;
   function Release_Name return String;
   function Version_Name return String;
   function Machine_Name return String;
end Posix_Tools.Host_Adapters.Host;
