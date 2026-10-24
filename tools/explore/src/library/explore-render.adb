with Explore.Format;
with Posix_Tools.File_Operations.Listing;

package body Explore.Render is

   package Listing renames Posix_Tools.File_Operations.Listing;
   package Model renames Explore.Model;
   package Previews renames Explore.Previews;
   package Screen renames Explore.Screen;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Listing.Entry_Kind;
   use type Model.Pane_Kind;
   use type Model.Pane_State;
   use type Previews.Preview_Kind;
   use type Unbounded.Unbounded_String;

   Title_Style  : constant Screen.Style := (Bold => True, others => <>);
   Path_Style   : constant Screen.Style := (Foreground => Screen.Blue, Bold => True, others => <>);
   Note_Style   : constant Screen.Style := (Dim => True, others => <>);
   Error_Style  : constant Screen.Style := (Foreground => Screen.Red, others => <>);
   Status_Style : constant Screen.Style := (Inverse => True, others => <>);
   Alert_Style  : constant Screen.Style := (Foreground => Screen.Red, Inverse => True, others => <>);

   --  Draw the information a file has in place of a listing.
   procedure Draw_Details
     (Into    : in out Screen.Grid;
      Item    : Listing.Listed_Entry;
      Path    : String;
      Context : Frame_Context;
      Shape   : Layout);

   procedure Draw_Pane
     (Into   : in out Screen.Grid;
      Item   : in out Model.Pane;
      Place  : Pane_Place;
      First  : Positive;
      Rows   : Natural;
      Active : Boolean;
      Text   : Labels);

   procedure Draw_Panel
     (Into    : in out Screen.Grid;
      Context : Frame_Context;
      Shape   : Layout);

   procedure Draw_Status
     (Into    : in out Screen.Grid;
      Browser : Model.Browser;
      Context : Frame_Context);

   function Entry_Style (Item : Listing.Listed_Entry) return Screen.Style;

   function Image (Value : Natural) return String;

   --  Write Text at Row from Column on, clipped to Width cells.
   procedure Write
     (Into   : in out Screen.Grid;
      Row    : Positive;
      Column : Positive;
      Width  : Natural;
      Text   : String;
      Style  : Screen.Style);

   function Content_Area (Shape : Layout) return Area is
      Place : constant Pane_Place := Shape.Places (Model.Preview_Pane);
   begin
      if not Place.Shown or else Shape.Height < 2 or else Place.Width < 3 then
         return (others => <>);
      end if;

      return (Row => Shape.First_Row + 1, Column => Place.Column + 1, Rows => Shape.Height - 1,
              Columns => Place.Width - 2);
   end Content_Area;

   procedure Draw
     (Into    : in out Screen.Grid;
      Browser : in out Model.Browser;
      Context : Frame_Context)
   is
      Rows    : constant Natural := Screen.Rows (Into);
      Columns : constant Natural := Screen.Columns (Into);
      Shape   : constant Layout := Layout_For (Rows, Columns);
      Current : Model.Pane renames Browser.Panes (Model.Current_Pane);
   begin
      Screen.Clear (Into);

      if Rows = 0 or else Columns = 0 then
         return;
      end if;

      declare
         Tabs  : constant String := Unbounded.To_String (Context.Tab_Line);
         Width : constant Natural := Natural'Min (Columns - 1, Screen.Width_Of (Tabs));
      begin
         Write (Into, 1, 2, Width, Tabs, Title_Style);
         Write (Into, 1, 2 + Width, Columns - 1 - Width, Unbounded.To_String (Current.Path), Path_Style);
      end;

      for Kind in Model.Pane_Kind loop
         if Shape.Places (Kind).Shown and then Shape.Height > 0 then
            if Kind = Model.Preview_Pane
              and then Browser.Panes (Kind).State = Model.Empty
              and then Model.Has_Selection (Current)
            then
               Draw_Details (Into, Model.Selected (Current), Model.Selected_Path (Current), Context, Shape);
            else
               Draw_Pane
                 (Into,
                  Browser.Panes (Kind),
                  Shape.Places (Kind),
                  Shape.First_Row,
                  Shape.Height,
                  Kind = Model.Current_Pane,
                  Context.Text);
            end if;
         end if;
      end loop;

      if Context.Panel_Open and then Shape.Height > 2 then
         Draw_Panel (Into, Context, Shape);
      end if;

      if Rows >= 2 then
         Draw_Status (Into, Browser, Context);
      end if;
   end Draw;

   procedure Draw_Details
     (Into    : in out Screen.Grid;
      Item    : Listing.Listed_Entry;
      Path    : String;
      Context : Frame_Context;
      Shape   : Layout)
   is
      Place   : constant Pane_Place := Shape.Places (Model.Preview_Pane);
      Content : constant Area := Content_Area (Shape);
      Shown   : constant Previews.Preview := Context.Preview;
      Current : constant Boolean := Unbounded.To_String (Shown.Path) = Path;
      Heading : constant String :=
        (if Item.Is_Link then "-> " & Unbounded.To_String (Item.Link_Target) & "  " else "")
        & (if Current then Unbounded.To_String (Shown.Description) else "");
   begin
      Write (Into, Shape.First_Row, Place.Column + 1, Place.Width - 1, Heading, Note_Style);

      if not Current or else Content.Rows = 0 then
         return;
      end if;

      case Shown.Kind is
         when Previews.Text_Preview | Previews.Binary_Preview =>
            for I in 1 .. Natural'Min (Content.Rows, Natural (Shown.Lines.Length)) loop
               Write
                 (Into, Content.Row + I - 1, Content.Column, Content.Columns, Shown.Lines (I),
                  (if Shown.Kind = Previews.Binary_Preview then Note_Style else Screen.Plain));
            end loop;
         when Previews.Image_Preview =>
            if Context.Image_Id > 0 and then Context.Image_Columns > 0 and then Context.Image_Rows > 0 then
               Screen.Put_Image
                 (Into, Content.Row, Content.Column, Context.Image_Id, Context.Image_Columns, Context.Image_Rows);
            end if;
         when Previews.Unreadable_Preview =>
            Write (Into, Content.Row, Content.Column, Content.Columns, Unbounded.To_String (Context.Text.Unreadable),
                   Error_Style);
         when Previews.No_Preview =>
            null;
      end case;
   end Draw_Details;

   procedure Draw_Pane
     (Into   : in out Screen.Grid;
      Item   : in out Model.Pane;
      Place  : Pane_Place;
      First  : Positive;
      Rows   : Natural;
      Active : Boolean;
      Text   : Labels)
   is
      Count : constant Natural := Model.Shown_Count (Item);
   begin
      if Rows = 0 or else Place.Width = 0 then
         return;
      end if;

      Model.Scroll (Item, Rows);

      if Count = 0 then
         case Item.State is
            when Model.Empty =>
               null;
            when Model.Loading =>
               Write (Into, First, Place.Column + 1, Place.Width - 1, Unbounded.To_String (Text.Loading), Note_Style);
            when Model.Failed =>
               Write
                 (Into, First, Place.Column + 1, Place.Width - 1, Unbounded.To_String (Text.Unreadable), Error_Style);
            when Model.Loaded =>
               Write (Into, First, Place.Column + 1, Place.Width - 1, Unbounded.To_String (Text.Empty), Note_Style);
         end case;

         return;
      end if;

      for Row in 0 .. Rows - 1 loop
         declare
            I : constant Natural := Item.Top + Row;
         begin
            exit when I > Count;

            declare
               Shown     : constant Listing.Listed_Entry := Model.Shown_Entry (Item, I);
               Name      : constant String :=
                 Unbounded.To_String (Shown.Name) & (if Shown.Kind = Listing.Directory_Entry then "/" else "");
               Style     : Screen.Style := Entry_Style (Shown);
               Size_Text : constant String :=
                 (if Active and then Shown.Kind = Listing.Regular_Entry and then Shown.Status.Available
                    and then Place.Width >= 20
                  then Format.Size_Image (Shown.Status.Size)
                  else "");
               Line      : constant Positive := First + Row;
               Name_Room : constant Natural :=
                 (if Size_Text'Length > 0 then Place.Width - Size_Text'Length - 3 else Place.Width - 2);
            begin
               if Model.Is_Marked (Item, Unbounded.To_String (Shown.Name)) then
                  Style.Foreground := Screen.Magenta;
                  Style.Bold := True;
               end if;

               if I = Item.Cursor then
                  if Active then
                     Style.Inverse := True;
                  else
                     Style.Background := Screen.Bright_Black;
                  end if;
               end if;

               Screen.Fill (Into, Line, Place.Column, Place.Width, (Style with delta Bold => False));
               Write (Into, Line, Place.Column + 1, Name_Room, Name, Style);

               if Size_Text'Length > 0 then
                  Write (Into, Line, Place.Column + Place.Width - Size_Text'Length - 1, Size_Text'Length, Size_Text,
                         (Style with delta Bold => False));
               end if;
            end;
         end;
      end loop;
   end Draw_Pane;

   procedure Draw_Panel
     (Into    : in out Screen.Grid;
      Context : Frame_Context;
      Shape   : Layout)
   is
      Columns : constant Natural := Screen.Columns (Into);
      Width   : constant Natural := Natural'Min (Columns, Natural'Max (40, Columns * 3 / 4));
      Left    : constant Positive := (Columns - Width) / 2 + 1;
      Lines   : constant Natural := Natural (Context.Panel_Lines.Length);
      Height  : constant Natural := Natural'Min (Shape.Height, Lines + 1);
      Top     : constant Positive := Shape.First_Row;
      Panel   : constant Screen.Style := (Background => Screen.Bright_Black, others => <>);
      First   : constant Positive :=
        (if Context.Panel_Cursor > Height - 1 then Context.Panel_Cursor - (Height - 1) + 1 else 1);
   begin
      for Row in Top .. Top + Height - 1 loop
         Screen.Fill (Into, Row, Left, Width, Panel);
      end loop;

      Write
        (Into, Top, Left + 1, Width - 2, Unbounded.To_String (Context.Panel_Title), (Panel with delta Bold => True));

      for I in 0 .. Height - 2 loop
         exit when First + I > Lines;

         declare
            Line  : constant Positive := First + I;
            Style : constant Screen.Style :=
              (if Line = Context.Panel_Cursor then (Panel with delta Inverse => True) else Panel);
         begin
            if Line = Context.Panel_Cursor then
               Screen.Fill (Into, Top + 1 + I, Left, Width, Style);
            end if;

            Write (Into, Top + 1 + I, Left + 1, Width - 2, Context.Panel_Lines (Line), Style);
         end;
      end loop;
   end Draw_Panel;

   procedure Draw_Status
     (Into    : in out Screen.Grid;
      Browser : Model.Browser;
      Context : Frame_Context)
   is
      Row     : constant Positive := Screen.Rows (Into);
      Columns : constant Natural := Screen.Columns (Into);
      Current : Model.Pane renames Browser.Panes (Model.Current_Pane);
      Filter  : constant String := Unbounded.To_String (Browser.Filter);
      Marked  : constant Natural := Natural (Current.Marked.Length);
      Right   : constant String :=
        (if Unbounded.Length (Context.Job_Line) = 0 then "" else Unbounded.To_String (Context.Job_Line) & "  ")
        & (if Marked = 0 then "" else Image (Marked) & " " & Unbounded.To_String (Context.Text.Marked) & "  ")
        & (if Unbounded.Length (Context.Search_Line) = 0 then "" else Unbounded.To_String (Context.Search_Line) & "  ")
        & (if Context.Editing or else Filter'Length = 0 then ""
           else Unbounded.To_String (Context.Text.Filter) & ": " & Filter & "  ")
        & Unbounded.To_String (Context.Prefix)
        & (if Unbounded.Length (Context.Prefix) > 0 then "  " else "")
        & Image (Current.Cursor) & "/" & Image (Model.Shown_Count (Current))
        & "  " & Unbounded.To_String (Context.Text.Quit_Hint) & " ";
      Left    : Unbounded.Unbounded_String;
      Style   : Screen.Style := Status_Style;
   begin
      if Context.Prompting then
         Left := Unbounded.To_Unbounded_String
           (" " & Unbounded.To_String (Context.Prompt_Label) & ": " & Unbounded.To_String (Context.Prompt_Text) & "_");
      elsif Unbounded.Length (Context.Question) > 0 then
         Left := " " & Context.Question;
         Style := Alert_Style;
      elsif Context.Editing then
         Left := Unbounded.To_Unbounded_String (" " & Unbounded.To_String (Context.Text.Filter) & ": " & Filter & "_");
      elsif Unbounded.Length (Context.Message) > 0 then
         Left := " " & Context.Message;
         Style := (if Context.Message_Is_Error then Alert_Style else Status_Style);
      elsif Model.Has_Selection (Current) then
         declare
            Item : constant Listing.Listed_Entry := Model.Selected (Current);
         begin
            Left := Unbounded.To_Unbounded_String (" " & Format.Mode_Image (Item));

            if Item.Status.Available then
               Unbounded.Append
                 (Left,
                  "  " & Unbounded.To_String (Context.Owner)
                  & "  " & Format.Size_Image (Item.Status.Size)
                  & "  " & Format.Time_Image (Item.Status.Modified_Seconds));
            end if;
         end;
      end if;

      Screen.Fill (Into, Row, 1, Columns, Status_Style);
      Write (Into, Row, 1, Columns, Unbounded.To_String (Left), Style);

      declare
         Right_Width : constant Natural := Screen.Width_Of (Right);
      begin
         if Right_Width + Screen.Width_Of (Unbounded.To_String (Left)) < Columns then
            Write (Into, Row, Columns - Right_Width + 1, Right_Width, Right, Status_Style);
         end if;
      end;
   end Draw_Status;

   function Entry_Style (Item : Listing.Listed_Entry) return Screen.Style is
   begin
      case Item.Kind is
         when Listing.Directory_Entry =>
            return (Foreground => Screen.Blue, Bold => True, others => <>);
         when Listing.Missing_Entry =>
            return (Foreground => Screen.Red, others => <>);
         when Listing.FIFO_Entry | Listing.Character_Device_Entry | Listing.Block_Device_Entry
            | Listing.Socket_Entry | Listing.Other_Entry
         =>
            return (Foreground => Screen.Yellow, others => <>);
         when Listing.Regular_Entry =>
            if Item.Is_Link then
               return (Foreground => Screen.Cyan, others => <>);
            elsif Item.Status.Available and then Item.Status.Mode mod 8#1000# / 8#100# mod 2 = 1 then
               return (Foreground => Screen.Green, others => <>);
            else
               return Screen.Plain;
            end if;
      end case;
   end Entry_Style;

   function Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   function Layout_For (Rows, Columns : Natural) return Layout is
      Result : Layout;
      Gap    : constant := 1;
   begin
      Result.Height := (if Rows >= 3 then Rows - 2 else 0);

      if Columns >= 80 then
         declare
            Parent_Width  : constant Natural := Columns / 8;
            Current_Width : constant Natural := Columns / 2;
         begin
            Result.Places (Model.Parent_Pane) := (True, 1, Parent_Width);
            Result.Places (Model.Current_Pane) := (True, Parent_Width + Gap + 1, Current_Width);
            Result.Places (Model.Preview_Pane) :=
              (True, Parent_Width + Current_Width + 2 * Gap + 1, Columns - Parent_Width - Current_Width - 2 * Gap);
         end;
      elsif Columns >= 50 then
         declare
            Current_Width : constant Natural := (Columns - Gap) / 2;
         begin
            Result.Places (Model.Current_Pane) := (True, 1, Current_Width);
            Result.Places (Model.Preview_Pane) := (True, Current_Width + Gap + 1, Columns - Current_Width - Gap);
         end;
      else
         Result.Places (Model.Current_Pane) := (True, 1, Columns);
      end if;

      return Result;
   end Layout_For;

   procedure Write
     (Into   : in out Screen.Grid;
      Row    : Positive;
      Column : Positive;
      Width  : Natural;
      Text   : String;
      Style  : Screen.Style)
   is
      Used : Natural;
   begin
      Screen.Put (Into, Row, Column, Text, Style, Width, Used);
   end Write;

end Explore.Render;
