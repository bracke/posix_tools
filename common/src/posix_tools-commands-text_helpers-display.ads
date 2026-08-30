package Posix_Tools.Commands.Text_Helpers.Display is
   function Display_Next_Column
     (Text     : String;
      Index    : Positive;
      Column   : Natural;
      Consumed : out Natural) return Natural;
end Posix_Tools.Commands.Text_Helpers.Display;
