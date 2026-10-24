package Posix_Tools.Commands.Text_Helpers.Display is
   function Display_Next_Column
     (Text     : String;
      Index    : Positive;
      Column   : Natural;
      Consumed : out Natural) return Natural;

   --  The number of columns a code point takes: 0 for a combining mark, 2 for
   --  a wide East Asian character, and 1 otherwise.
   function Display_Width (Code_Point : Long_Long_Integer) return Natural;
end Posix_Tools.Commands.Text_Helpers.Display;
