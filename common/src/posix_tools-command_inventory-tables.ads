package Posix_Tools.Command_Inventory.Tables
  with SPARK_Mode => On
is
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

   function Posix_Status (Index : Positive) return String
     with
       Pre  => Index <= Command_Count,
       Post => Posix_Status'Result'Length in 1 .. 26;
end Posix_Tools.Command_Inventory.Tables;
