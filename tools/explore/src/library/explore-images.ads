--  Showing an image in the preview pane through the terminal's Kitty
--  graphics: the image is sent once and placed virtually, and the pane's cells
--  are filled with Unicode placeholders that say which image, row, and column
--  each shows. The placeholders are ordinary text, so the terminal and tmux
--  move, redraw, and clear them like any other.
package Explore.Images is
   --  The placeholder character, and how many rows or columns its diacritics
   --  can name.
   Placeholder     : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#10EEEE#);
   Diacritic_Count : constant := 297;

   --  The combining character that names row or column Value of an image.
   function Diacritic (Value : Natural) return Wide_Wide_Character
     with Pre => Value < Diacritic_Count;

   --  The commands that hand the terminal Data, a PNG image, as image Id and
   --  place it virtually across Columns by Rows cells, asking for no reply.
   --  Inside tmux each command is passed through to the outer terminal.
   function Transmit_PNG (Id : Positive; Data : String; Columns, Rows : Positive; In_Tmux : Boolean) return String;

   --  Free image Id and its data in the terminal.
   function Delete (Id : Positive; In_Tmux : Boolean) return String;

   --  Free every image the program sent.
   function Delete_All (In_Tmux : Boolean) return String;

   --  The width and height a PNG's header gives; False when Data is no PNG.
   function PNG_Size (Data : String; Width, Height : out Natural) return Boolean;

   function Is_PNG (Data : String) return Boolean;
   function Is_JPEG (Data : String) return Boolean;

   --  The largest Columns by Rows of at most Max_Columns by Max_Rows cells,
   --  of Cell_Width by Cell_Height pixels each, that show an image of
   --  Width by Height pixels without stretching it; never more cells than the
   --  image has pixels, so a small image is not blown up.
   procedure Fit
     (Width, Height           : Positive;
      Cell_Width, Cell_Height : Positive;
      Max_Columns, Max_Rows   : Positive;
      Columns, Rows           : out Positive);

   function Base64 (Data : String) return String;
end Explore.Images;
