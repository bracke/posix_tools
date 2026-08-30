private package Posix_Tools.Text.Printf_Formats.Number_Images.Float_Images is
   function Fixed_Float_Image
     (Text        : String;
      Precision   : Natural;
      Always_Sign : Boolean;
      Blank_Sign  : Boolean;
      Ok          : out Boolean) return String;

   function General_Float_Image
     (Text        : String;
      Precision   : Natural;
      Upper       : Boolean;
      Always_Sign : Boolean;
      Blank_Sign  : Boolean;
      Alternate   : Boolean;
      Ok          : out Boolean) return String;

   function Scientific_Float_Image
     (Text        : String;
      Precision   : Natural;
      Upper       : Boolean;
      Always_Sign : Boolean;
      Blank_Sign  : Boolean;
      Alternate   : Boolean;
      Ok          : out Boolean) return String;
end Posix_Tools.Text.Printf_Formats.Number_Images.Float_Images;
