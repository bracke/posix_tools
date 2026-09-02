package Posix_Tools.Command_Inventory
  with SPARK_Mode => On
is
   Command_Count : constant Positive := 77;

   function Executable (Index : Positive) return String
     with
       Pre  => Index <= Command_Count,
       Post => Executable'Result'Length in 1 .. 9;

   function Crate (Index : Positive) return String
     with
       Pre  => Index <= Command_Count,
       Post => Crate'Result'Length in 1 .. 21;

   function Package_Name (Index : Positive) return String
     with
       Pre  => Index <= Command_Count,
       Post => Package_Name'Result'Length in 1 .. 34;

   function Manifest_Path (Index : Positive) return String
     with
       Pre  => Index <= Command_Count,
       Post => Manifest_Path'Result'Length in 1 .. 27;

   function Project_File_Path (Index : Positive) return String
     with
       Pre  => Index <= Command_Count,
       Post => Project_File_Path'Result'Length in 1 .. 41;

   function Documentation_Path (Index : Positive) return String
     with
       Pre  => Index <= Command_Count,
       Post => Documentation_Path'Result'Length in 1 .. 26;

   function Release_Included (Index : Positive) return Boolean
     with Pre => Index <= Command_Count;

   function Posix_Status (Index : Positive) return String
     with
       Pre  => Index <= Command_Count,
       Post => Posix_Status'Result'Length in 1 .. 26;

   function Has_Help (Index : Positive) return Boolean
     with Pre => Index <= Command_Count;

   function Has_Version (Index : Positive) return Boolean
     with Pre => Index <= Command_Count;

   function Has_Identity (Index : Positive) return Boolean
     with Pre => Index <= Command_Count;

   function Contains_Executable (Name : String) return Boolean;
end Posix_Tools.Command_Inventory;
