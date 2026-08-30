package Posix_Tools.Version
  with SPARK_Mode => On
is
   pragma Pure;

   Version_String : constant String := "0.1.0";
   Project_Name   : constant String := "posix-tools";

   function Is_Project_Name (Value : String) return Boolean is
     (Value = Project_Name);

   function Is_Version_String (Value : String) return Boolean is
     (Value = Version_String);
end Posix_Tools.Version;
