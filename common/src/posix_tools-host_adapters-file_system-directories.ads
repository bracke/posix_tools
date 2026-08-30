with Interfaces;

private package Posix_Tools.Host_Adapters.File_System.Directories is
   function Create_Device
     (Path   : String;
      Kind   : Special_File_Kind;
      Device : Interfaces.Unsigned_64;
      Mode   : Natural) return Boolean;
   procedure Create_Directory (Path : String);
   function Create_FIFO (Path : String; Mode : Natural) return Boolean;
   function Create_Socket (Path : String; Mode : Natural) return Boolean;
   function Create_Hard_Link (Source : String; Target : String) return Boolean;
   function Create_Link (Source : String; Target : String) return Boolean;
   procedure Create_Path (Path : String);
   procedure Delete_Directory (Path : String);
   procedure Delete_File (Path : String);
   function Delete_Link (Path : String) return Boolean;
   procedure Delete_Tree (Path : String);
   function Set_Ownership (Path : String; User : Natural; Group : Natural) return Boolean;
   function Set_Permissions (Path : String; Mode : Natural) return Boolean;

   generic
      with procedure Action
        (Name      : String;
         Full_Name : String;
         Stop      : in out Boolean);
   procedure For_Each_Directory_Entry (Path : String; Ok : out Boolean);
end Posix_Tools.Host_Adapters.File_System.Directories;
