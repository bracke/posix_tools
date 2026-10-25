with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Explore.Model;
with Explore.Previews;
with Explore.Screen;
with Explore.String_Vectors;
with Explore.Themes;

--  Drawing a frame: where the panes go for the terminal's width, and what
--  each shows.
package Explore.Render is
   --  Interface text, looked up once in the user's locale.
   type Labels is record
      Quit_Hint  : Ada.Strings.Unbounded.Unbounded_String;
      Loading    : Ada.Strings.Unbounded.Unbounded_String;
      Unreadable : Ada.Strings.Unbounded.Unbounded_String;
      Empty      : Ada.Strings.Unbounded.Unbounded_String;
      Filter     : Ada.Strings.Unbounded.Unbounded_String;
      Marked     : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Pane_Place is record
      Shown  : Boolean := False;
      Column : Positive := 1;
      Width  : Natural := 0;
   end record;

   type Pane_Places is array (Explore.Model.Pane_Kind) of Pane_Place;

   type Layout is record
      Places : Pane_Places;
      --  The rows the panes take, between the title and the status line.
      First_Row : Positive := 2;
      Height    : Natural := 0;
   end record;

   --  Three panes from 80 columns, the current and the preview from 50, and
   --  the current alone below that.
   function Layout_For (Rows, Columns : Natural) return Layout;

   type Area is record
      Row     : Positive := 1;
      Column  : Positive := 1;
      Rows    : Natural := 0;
      Columns : Natural := 0;
   end record;

   --  Where the preview pane shows a file's content: below its description
   --  line, inside the pane's margin. Empty when there is no preview pane.
   function Content_Area (Shape : Layout) return Area;

   package Id_Vectors is new Ada.Containers.Vectors (Positive, Natural);

   type Frame_Context is record
      Text    : Labels;
      Colors  : Explore.Themes.Theme := Explore.Themes.Default_Theme;
      --  The owner and group of the selected entry, as names where known.
      Owner   : Ada.Strings.Unbounded.Unbounded_String;
      --  Typing into the filter: the status line shows what is typed.
      Editing : Boolean := False;
      --  The prefix key waiting for its second key.
      Prefix  : Ada.Strings.Unbounded.Unbounded_String;
      --  What the search shown in the current pane looks for, empty when it
      --  shows a directory, and whether it is still looking.
      Search_Line : Ada.Strings.Unbounded.Unbounded_String;
      --  The tabs, when there is more than one, the active one bracketed.
      Tab_Line : Ada.Strings.Unbounded.Unbounded_String;
      --  A line of text being typed for an operation, under its label.
      Prompting    : Boolean := False;
      Prompt_Label : Ada.Strings.Unbounded.Unbounded_String;
      Prompt_Text  : Ada.Strings.Unbounded.Unbounded_String;
      --  A question waiting for a key, such as a confirmation.
      Question     : Ada.Strings.Unbounded.Unbounded_String;
      --  What the last operation had to say, shown until the next key.
      Message      : Ada.Strings.Unbounded.Unbounded_String;
      Message_Is_Error : Boolean := False;
      --  The running job, as the status line shows it.
      Job_Line     : Ada.Strings.Unbounded.Unbounded_String;
      --  The preview of the selected file, when it has arrived.
      Preview      : Explore.Previews.Preview;
      --  The image the terminal holds for it, and the cells it is placed
      --  in; no image when Image_Id is zero.
      Image_Id     : Natural range 0 .. 255 := 0;
      Image_Columns : Natural := 0;
      Image_Rows   : Natural := 0;
      --  The jobs panel, drawn over the panes while it is open: its title,
      --  its lines, the line the cursor is on, and the job each line stands
      --  for, zero for a line that stands for none.
      Panel_Open   : Boolean := False;
      Panel_Title  : Ada.Strings.Unbounded.Unbounded_String;
      Panel_Lines  : Explore.String_Vectors.Vector;
      Panel_Ids    : Id_Vectors.Vector;
      Panel_Cursor : Natural := 0;
   end record;

   --  A screen smaller than this is left blank: there is no room for the
   --  heading, a pane and the status line, nor for a name beside its size.
   Min_Rows    : constant := 3;
   Min_Columns : constant := 12;

   --  The rows each pane of Browser lists its entries in on a screen of Rows
   --  by Columns: none for a pane not shown, nor for a preview that shows a
   --  file's details instead.
   function Listed_Heights (Browser : Explore.Model.Browser; Rows, Columns : Natural) return Explore.Model.Pane_Heights;

   --  Draw the whole frame for Browser into Into. Each pane is drawn from
   --  where it is scrolled to, so scroll them to Listed_Heights first.
   procedure Draw
     (Into    : in out Explore.Screen.Grid;
      Browser : Explore.Model.Browser;
      Context : Frame_Context);
end Explore.Render;
