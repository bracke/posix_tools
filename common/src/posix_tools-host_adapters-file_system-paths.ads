with Ada.Strings.Unbounded;

private package Posix_Tools.Host_Adapters.File_System.Paths is
   function Containing_Directory (Path : String) return String;
   function Path_Name_Limit (Path : String; Available : out Boolean) return Natural;
   function Exists (Path : String) return Boolean;
   function Full_Name (Path : String) return String;
   function Join (Left : String; Right : String) return String;
   function Physical_Current_Directory return String;
   function Try_Physical_Current_Directory (Path : out String; Last : out Natural) return Boolean;
   function Path_Names_Current_Directory (Path : String) return Boolean;
   function Read_Link_Target (Path : String; Target : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   function Real_Path (Path : String) return String;
   procedure Rename (Old_Path : String; New_Path : String);
   function Same_File (Left : String; Right : String) return Boolean;
   function Simple_Name (Path : String) return String;
end Posix_Tools.Host_Adapters.File_System.Paths;
