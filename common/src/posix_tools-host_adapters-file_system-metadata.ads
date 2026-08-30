private package Posix_Tools.Host_Adapters.File_System.Metadata is
   function Allocated_Size (Path : String; Available : out Boolean) return Long_Long_Integer;
   function Device_Id (Path : String; Available : out Boolean) return Long_Long_Integer;
   procedure File_Ownership
     (Path      : String;
      User      : out Natural;
      Group     : out Natural;
      Available : out Boolean);
   function File_Name_Limit (Path : String; Available : out Boolean) return Natural;
   function File_Permission_Bits (Path : String; Available : out Boolean) return Natural;
   function File_System_Capacity (Path : String) return Volume_Capacity;
   function Group_Id_For_Name (Name : String; Found : out Boolean) return Natural;
   function Group_Name_For_Current_User return String;
   function Group_Name_For_Id (Id : Natural) return String;
   function Is_Link (Path : String) return Boolean;
   function Kind (Path : String) return File_Kind;
   function Size (Path : String) return Long_Long_Integer;
   function Special_File_Info_Of (Path : String) return Special_File_Info;
   function User_Id_For_Name (Name : String; Found : out Boolean) return Natural;
   function User_Name_For_Id (Id : Natural) return String;
end Posix_Tools.Host_Adapters.File_System.Metadata;
