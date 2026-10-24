with Ada.Strings.Unbounded;
with Explore.Model;
with Explore.Screen;

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

   type Frame_Context is record
      Text    : Labels;
      --  The owner and group of the selected entry, as names where known.
      Owner   : Ada.Strings.Unbounded.Unbounded_String;
      --  Typing into the filter: the status line shows what is typed.
      Editing : Boolean := False;
      --  The prefix key waiting for its second key.
      Prefix  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Draw the whole frame for Browser into Into, scrolling each pane so its
   --  cursor is on screen.
   procedure Draw
     (Into    : in out Explore.Screen.Grid;
      Browser : in out Explore.Model.Browser;
      Context : Frame_Context);
end Explore.Render;
