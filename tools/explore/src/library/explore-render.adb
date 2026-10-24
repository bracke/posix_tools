with Explore.Format;
with Posix_Tools.File_Operations.Listing;

package body Explore.Render is
   package Listing renames Posix_Tools.File_Operations.Listing;
   package Model renames Explore.Model;
   package Screen renames Explore.Screen;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Listing.Entry_Kind;
   use type Model.Pane_Kind;
   use type Model.Pane_State;

   Title_Style  : constant Screen.Style := (Bold => True, others => <>);
   Path_Style   : constant Screen.Style := (Foreground => Screen.Blue, Bold => True, others => <>);
   Note_Style   : constant Screen.Style := (Dim => True, others => <>);
   Error_Style  : constant Screen.Style := (Foreground => Screen.Red, others => <>);
   Status_Style : constant Screen.Style := (Inverse => True, others => <>);

   function Image (Value : Natural) return String;

   --  Draw the information a file has in place of a listing.
   procedure Draw_Details
     (Into  : in out Screen.Grid;
      Item  : Listing.Listed_Entry;
      Place : Pane_Place;
      First : Positive;
      Rows  : Natural);

   procedure Draw_Pane
     (Into   : in out Screen.Grid;
      Item   : in out Model.Pane;
      Place  : Pane_Place;
      First  : Positive;
      Rows   : Natural;
      Active : Boolean;
      Text   : Labels);

   procedure Draw_Status
     (Into    : in out Screen.Grid;
      Browser : Model.Browser;
      Context : Frame_Context);

   function Entry_Style (Item : Listing.Listed_Entry) return Screen.Style;

   --  Write Text at Row from Column on, clipped to Width cells.
   procedure Write
     (Into   : in out Screen.Grid;
      Row    : Positive;
      Column : Positive;
      Width  : Natural;
      Text   : String;
      Style  : Screen.Style);

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

      Write (Into, 1, 1, Columns, " ", Title_Style);
      Write (Into, 1, 2, Columns - 1, Unbounded.To_String (Current.Path), Path_Style);

      for Kind in Model.Pane_Kind loop
         if Shape.Places (Kind).Shown and then Shape.Height > 0 then
            if Kind = Model.Preview_Pane
              and then Browser.Panes (Kind).State = Model.Empty
              and then Model.Has_Selection (Current)
            then
               Draw_Details (Into, Model.Selected (Current), Shape.Places (Kind), Shape.First_Row, Shape.Height);
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

      if Rows >= 2 then
         Draw_Status (Into, Browser, Context);
      end if;
   end Draw;

   procedure Draw_Details
     (Into  : in out Screen.Grid;
      Item  : Listing.Listed_Entry;
      Place : Pane_Place;
      First : Positive;
      Rows  : Natural)
   is
      Lines : constant array (1 .. 4) of Unbounded.Unbounded_String :=
        [Unbounded.To_Unbounded_String (Format.Mode_Image (Item)),
         Unbounded.To_Unbounded_String
           (if Item.Status.Available
            then Format.Size_Image (Item.Status.Size) & " (" & Format.Count_Image (Item.Status.Size) & ")"
            else ""),
         Unbounded.To_Unbounded_String
           (if Item.Status.Available then Format.Time_Image (Item.Status.Modified_Seconds) else ""),
         Unbounded.To_Unbounded_String
           (if Item.Is_Link then "-> " & Unbounded.To_String (Item.Link_Target) else "")];
   begin
      for I in Lines'Range loop
         exit when I > Rows;
         Write (Into, First + I - 1, Place.Column + 1, Place.Width - 1, Unbounded.To_String (Lines (I)), Note_Style);
      end loop;
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

   procedure Draw_Status
     (Into    : in out Screen.Grid;
      Browser : Model.Browser;
      Context : Frame_Context)
   is
      Row     : constant Positive := Screen.Rows (Into);
      Columns : constant Natural := Screen.Columns (Into);
      Current : Model.Pane renames Browser.Panes (Model.Current_Pane);
      Filter  : constant String := Unbounded.To_String (Browser.Filter);
      Right   : constant String :=
        (if Context.Editing or else Filter'Length = 0 then ""
         else Unbounded.To_String (Context.Text.Filter) & ": " & Filter & "  ")
        & Unbounded.To_String (Context.Prefix)
        & (if Unbounded.Length (Context.Prefix) > 0 then "  " else "")
        & Image (Current.Cursor) & "/" & Image (Model.Shown_Count (Current))
        & "  " & Unbounded.To_String (Context.Text.Quit_Hint) & " ";
      Left    : Unbounded.Unbounded_String;
   begin
      if Context.Editing then
         Left := Unbounded.To_Unbounded_String (" " & Unbounded.To_String (Context.Text.Filter) & ": " & Filter & "_");
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
      Write (Into, Row, 1, Columns, Unbounded.To_String (Left), Status_Style);

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
