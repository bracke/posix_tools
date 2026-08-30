package Posix_Tools.Host_Adapters.File_System.IO is
   function Can_Open_For_Read (Path : String) return Boolean;

   procedure Copy_Regular_File
     (Source : String;
      Target : String;
      Status : out Copy_File_Status);

   procedure Write_File
     (Path        : String;
      Text        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean);
end Posix_Tools.Host_Adapters.File_System.IO;
