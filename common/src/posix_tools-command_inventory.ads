package Posix_Tools.Command_Inventory is
   Command_Count : constant Positive := 55;

   function Executable (Index : Positive) return String
     with Pre => Index <= Command_Count;

   function Crate (Index : Positive) return String
     with Pre => Index <= Command_Count;

   function Package_Name (Index : Positive) return String
     with Pre => Index <= Command_Count;

   function Manifest_Path (Index : Positive) return String
     with Pre => Index <= Command_Count;

   function Project_File_Path (Index : Positive) return String
     with Pre => Index <= Command_Count;

   function Documentation_Path (Index : Positive) return String
     with Pre => Index <= Command_Count;

   function Release_Included (Index : Positive) return Boolean
     with Pre => Index <= Command_Count;

   function Posix_Status (Index : Positive) return String
     with Pre => Index <= Command_Count;

   function Has_Help (Index : Positive) return Boolean
     with Pre => Index <= Command_Count;

   function Has_Version (Index : Positive) return Boolean
     with Pre => Index <= Command_Count;

   function Has_Identity (Index : Positive) return Boolean
     with Pre => Index <= Command_Count;

   function Contains_Executable (Name : String) return Boolean;
end Posix_Tools.Command_Inventory;
