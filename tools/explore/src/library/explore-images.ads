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

   --  The encodings an image can be sent in. PNG is Kitty's own f=100; JPEG
   --  and GIF are bracke-terminal's private f=1001 and f=1002, which it
   --  advertises as kgfx-jpeg and kgfx-gif and decodes itself.
   type Image_Format is (PNG_Format, JPEG_Format, GIF_Format);

   --  The f= code of a format.
   function Format_Code (Format : Image_Format) return Positive;

   --  The commands that hand the terminal Data, an image in Format, as image
   --  Id and place it virtually, as placement 1, across Columns by Rows
   --  cells, asking for no reply. Inside tmux each command is passed through
   --  to the outer terminal.
   function Transmit
     (Id      : Positive;
      Format  : Image_Format;
      Data    : String;
      Columns : Positive;
      Rows    : Positive;
      In_Tmux : Boolean) return String;

   function Transmit_PNG (Id : Positive; Data : String; Columns, Rows : Positive; In_Tmux : Boolean) return String is
     (Transmit (Id, PNG_Format, Data, Columns, Rows, In_Tmux));

   --  Place image Id, already sent, across Columns by Rows cells instead.
   function Place (Id : Positive; Columns, Rows : Positive; In_Tmux : Boolean) return String;

   --  Free image Id and its data in the terminal.
   function Delete (Id : Positive; In_Tmux : Boolean) return String;

   --  Free every image the program sent.
   function Delete_All (In_Tmux : Boolean) return String;

   --  The width and height a PNG's header gives; False when Data is no PNG.
   function PNG_Size (Data : String; Width, Height : out Natural) return Boolean;

   function Is_PNG (Data : String) return Boolean;
   function Is_JPEG (Data : String) return Boolean;
   function Is_GIF (Data : String) return Boolean;

   --  The width and height a JPEG's frame header gives, found by walking its
   --  markers; False when there is none in Data.
   function JPEG_Size (Data : String; Width, Height : out Natural) return Boolean;

   --  The width and height of a GIF's logical screen.
   function GIF_Size (Data : String; Width, Height : out Natural) return Boolean;

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
