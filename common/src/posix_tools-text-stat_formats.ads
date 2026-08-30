package Posix_Tools.Text.Stat_Formats is
   function Render_Format
     (Format               : String;
      Path                 : String;
      Mode_Image           : String;
      Kind_Name            : String;
      Group_Id_Image       : String;
      Size_Image           : String;
      Creation_Time_Image  : String;
      Creation_Epoch_Image : String;
      Access_Time_Image    : String;
      Access_Epoch_Image   : String;
      Modify_Time_Image    : String;
      Modify_Epoch_Image   : String;
      User_Id_Image        : String) return String;
end Posix_Tools.Text.Stat_Formats;
