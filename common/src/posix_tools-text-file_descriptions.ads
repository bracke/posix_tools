package Posix_Tools.Text.File_Descriptions is
   function Content_Description
     (Data       : String;
      Mime_Mode  : Boolean;
      Magic_Text : String;
      Has_Magic  : Boolean) return String;
end Posix_Tools.Text.File_Descriptions;
