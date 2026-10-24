with Ada.Containers.Vectors;

--  The screen as a grid of cells, and the shortest output that turns what the
--  terminal shows into what a frame should show.
--
--  A frame is drawn into a grid from scratch; Render compares it with the grid
--  the terminal was last brought to and writes only the cells that differ.
--
--  One cell holds one character. A wide character takes two cells, the second
--  marked as its continuation. Combining marks have no cell of their own and
--  are left out, and control characters are shown as '?'.
package Explore.Screen is
   --  A terminal colour: an index into its 256-colour palette, or its default.
   type Color is range -1 .. 255;

   Default_Color : constant Color := -1;
   Black         : constant Color := 0;
   Red           : constant Color := 1;
   Green         : constant Color := 2;
   Yellow        : constant Color := 3;
   Blue          : constant Color := 4;
   Magenta       : constant Color := 5;
   Cyan          : constant Color := 6;
   White         : constant Color := 7;
   Bright_Black  : constant Color := 8;

   type Style is record
      Foreground : Color := Default_Color;
      Background : Color := Default_Color;
      Bold       : Boolean := False;
      Dim        : Boolean := False;
      Underline  : Boolean := False;
      Inverse    : Boolean := False;
   end record;

   Plain : constant Style := (others => <>);

   type Cell is record
      Code         : Wide_Wide_Character := ' ';
      Item_Style   : Style := Plain;
      --  The right half of the wide character in the cell before it.
      Continuation : Boolean := False;
   end record;

   type Grid is private;

   function Rows (Self : Grid) return Natural;
   function Columns (Self : Grid) return Natural;

   --  Give Self the size of the terminal, every cell blank.
   procedure Resize (Self : in out Grid; Rows, Columns : Natural)
     with Post => Screen.Rows (Self) = Rows and then Screen.Columns (Self) = Columns;

   procedure Clear (Self : in out Grid);

   function Cell_At (Self : Grid; Row, Column : Positive) return Cell
     with Pre => Row <= Rows (Self) and then Column <= Columns (Self);

   --  Write the UTF-8 Text from Column on, in at most Width cells; a wide
   --  character that would not fit whole is left out. Used is the number of
   --  cells written. Cells beyond the grid are never written.
   procedure Put
     (Self       : in out Grid;
      Row        : Positive;
      Column     : Positive;
      Text       : String;
      Item_Style : Style;
      Width      : Natural;
      Used       : out Natural);

   --  Blank Width cells from Column on in Item_Style.
   procedure Fill
     (Self       : in out Grid;
      Row        : Positive;
      Column     : Positive;
      Width      : Natural;
      Item_Style : Style);

   --  The number of cells the UTF-8 Text takes, as Put would write it.
   function Width_Of (Text : String) return Natural;

   --  The longest prefix of the UTF-8 Text that takes at most Width cells.
   function Clipped (Text : String; Width : Natural) return String;

   --  The output that brings a terminal showing Shown to show Wanted, and
   --  Shown made a copy of Wanted. With Full, or when the two differ in size,
   --  every cell is written.
   function Render (Shown : in out Grid; Wanted : Grid; Full : Boolean := False) return String;

private
   package Cell_Vectors is new Ada.Containers.Vectors (Positive, Cell);

   type Grid is record
      Height : Natural := 0;
      Width  : Natural := 0;
      Cells  : Cell_Vectors.Vector;
   end record;
end Explore.Screen;
