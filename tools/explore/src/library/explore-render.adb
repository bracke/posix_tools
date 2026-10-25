with Explore.Format;
with Explore.Syntax;
with Posix_Tools.File_Operations.Listing;
with Posix_Tools.Text.Numeric_Images;

package body Explore.Render is

   package Listing renames Posix_Tools.File_Operations.Listing;
   package Model renames Explore.Model;
   package Previews renames Explore.Previews;
   package Syntax renames Explore.Syntax;
   package Screen renames Explore.Screen;
   package Themes renames Explore.Themes;
   package Unbounded renames Ada.Strings.Unbounded;

   use all type Themes.Theme_Role;

   use type Listing.Entry_Kind;
   use type Screen.Color;
   use type Model.Pane_Kind;
   use type Model.Pane_State;
   use type Previews.Preview_Kind;
   use type Unbounded.Unbounded_String;

   --  Below this width a pane has no room for sizes beside the names.
   Min_Size_Column_Width : constant := 20;

   --  The jobs panel takes this share of the width, but never less than
   --  Min_Panel_Width columns where the screen has them.
   Panel_Share_Numerator   : constant := 3;
   Panel_Share_Denominator : constant := 4;
   Min_Panel_Width         : constant := 40;

   --  The screen widths from which three panes are shown, and two.
   Three_Pane_Columns : constant := 80;
   Two_Pane_Columns   : constant := 50;

   --  The owner-execute bit of a file's mode.
   Owner_Execute_Bit : constant := 8#100#;

   function Owner_Can_Execute (Mode : Natural) return Boolean is (Mode / Owner_Execute_Bit mod 2 = 1);

   function Token_Style (Colors : Themes.Theme; Kind : Syntax.Token_Kind) return Screen.Style is
     (case Kind is
        when Syntax.Plain => Screen.Plain,
        when Syntax.Keyword => Colors (Keyword_Role),
        when Syntax.String_Literal => Colors (String_Role),
        when Syntax.Comment => Colors (Comment_Role),
        when Syntax.Number => Colors (Number_Role),
        when Syntax.Heading => Colors (Heading_Role));

   --  Base with what Top sets laid over it: its colours where it has them,
   --  and each of its attributes that is on.
   function Overlay (Base, Top : Screen.Style) return Screen.Style is
     ((Foreground => (if Top.Foreground = Screen.Default_Color then Base.Foreground else Top.Foreground),
       Background => (if Top.Background = Screen.Default_Color then Base.Background else Top.Background),
       Bold       => Base.Bold or else Top.Bold,
       Dim        => Base.Dim or else Top.Dim,
       Underline  => Base.Underline or else Top.Underline,
       Inverse    => Base.Inverse or else Top.Inverse));

   --  Draw the information a file has in place of a listing.
   procedure Draw_Details
     (Into    : in out Screen.Grid;
      Item    : Listing.Listed_Entry;
      Path    : String;
      Context : Frame_Context;
      Shape   : Layout);

   procedure Draw_Pane
     (Into   : in out Screen.Grid;
      Item   : Model.Pane;
      Place  : Pane_Place;
      First  : Positive;
      Rows   : Natural;
      Active : Boolean;
      Text   : Labels;
      Colors : Themes.Theme);

   procedure Draw_Panel
     (Into    : in out Screen.Grid;
      Context : Frame_Context;
      Shape   : Layout);

   procedure Draw_Status
     (Into    : in out Screen.Grid;
      Browser : Model.Browser;
      Context : Frame_Context);

   function Entry_Style (Colors : Themes.Theme; Item : Listing.Listed_Entry) return Screen.Style;

   function Image (Value : Natural) return String renames Posix_Tools.Text.Numeric_Images.Natural_Image;

   --  Whether the preview pane shows the selected file's details in place
   --  of a listing.
   function Shows_Details (Browser : Model.Browser) return Boolean is
     (Browser.Panes (Model.Preview_Pane).State = Model.Empty
      and then Model.Has_Selection (Browser.Panes (Model.Current_Pane)));

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
      Browser : Model.Browser;
      Context : Frame_Context)
   is
      Rows    : constant Natural := Screen.Rows (Into);
      Columns : constant Natural := Screen.Columns (Into);
      Shape   : constant Layout := Layout_For (Rows, Columns);
      Heights : constant Model.Pane_Heights := Listed_Heights (Browser, Rows, Columns);
      Current : Model.Pane renames Browser.Panes (Model.Current_Pane);
   begin
      Screen.Clear (Into);

      if Rows < Min_Rows or else Columns < Min_Columns then
         return;
      end if;

      declare
         Tabs  : constant String := Unbounded.To_String (Context.Tab_Line);
         Width : constant Natural := Natural'Min (Columns - 1, Screen.Width_Of (Tabs));
      begin
         Write (Into, 1, 2, Width, Tabs, Context.Colors (Header_Role));
         Write
           (Into, 1, 2 + Width, Columns - 1 - Width, Unbounded.To_String (Current.Path), Context.Colors (Info_Role));
      end;

      for Kind in Model.Pane_Kind loop
         if Shape.Places (Kind).Shown and then Shape.Height > 0 then
            if Kind = Model.Preview_Pane and then Shows_Details (Browser) then
               Draw_Details (Into, Model.Selected (Current), Model.Selected_Path (Current), Context, Shape);
            elsif Heights (Kind) > 0 then
               Draw_Pane
                 (Into,
                  Browser.Panes (Kind),
                  Shape.Places (Kind),
                  Shape.First_Row,
                  Heights (Kind),
                  Kind = Model.Current_Pane,
                  Context.Text,
                  Context.Colors);
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
      Write (Into, Shape.First_Row, Place.Column + 1, Place.Width - 1, Heading, Context.Colors (Muted_Role));

      if not Current or else Content.Rows = 0 then
         return;
      end if;

      case Shown.Kind is
         when Previews.Text_Preview =>
            declare
               State : Syntax.Line_State;
               Spans : Syntax.Span_Vectors.Vector;
            begin
               for I in 1 .. Natural'Min (Content.Rows, Natural (Shown.Lines.Length)) loop
                  declare
                     Line : constant String := Shown.Lines (I);
                  begin
                     Write (Into, Content.Row + I - 1, Content.Column, Content.Columns, Line, Screen.Plain);
                     Syntax.Tokenize (Line, Shown.Language, State, Spans);

                     --  Each coloured run is written again over the plain line,
                     --  from the column its first byte falls in.
                     for Run of Spans loop
                        declare
                           Before : constant Natural := Screen.Width_Of (Line (Line'First .. Run.First - 1));
                        begin
                           if Before < Content.Columns then
                              Write
                                (Into, Content.Row + I - 1, Content.Column + Before, Content.Columns - Before,
                                 Line (Run.First .. Run.Last), Token_Style (Context.Colors, Run.Kind));
                           end if;
                        end;
                     end loop;
                  end;
               end loop;
            end;
         when Previews.Binary_Preview | Previews.Archive_Preview =>
            for I in 1 .. Natural'Min (Content.Rows, Natural (Shown.Lines.Length)) loop
               Write
                 (Into, Content.Row + I - 1, Content.Column, Content.Columns, Shown.Lines (I),
                  (if Shown.Kind = Previews.Binary_Preview then Context.Colors (Muted_Role) else Screen.Plain));
            end loop;
         when Previews.Image_Preview =>
            if Context.Image_Id > 0 and then Context.Image_Columns > 0 and then Context.Image_Rows > 0 then
               Screen.Put_Image
                 (Into, Content.Row, Content.Column, Context.Image_Id, Context.Image_Columns, Context.Image_Rows);
            end if;
         when Previews.Unreadable_Preview =>
            Write (Into, Content.Row, Content.Column, Content.Columns, Unbounded.To_String (Context.Text.Unreadable),
                   Context.Colors (Error_Role));
         when Previews.No_Preview =>
            null;
      end case;
   end Draw_Details;

   procedure Draw_Pane
     (Into   : in out Screen.Grid;
      Item   : Model.Pane;
      Place  : Pane_Place;
      First  : Positive;
      Rows   : Natural;
      Active : Boolean;
      Text   : Labels;
      Colors : Themes.Theme)
   is
      Count : constant Natural := Model.Shown_Count (Item);
   begin
      if Count = 0 then
         case Item.State is
            when Model.Empty =>
               null;
            when Model.Loading =>
               Write
                 (Into, First, Place.Column + 1, Place.Width - 1, Unbounded.To_String (Text.Loading),
                  Colors (Muted_Role));
            when Model.Failed =>
               Write
                 (Into, First, Place.Column + 1, Place.Width - 1, Unbounded.To_String (Text.Unreadable),
                  Colors (Error_Role));
            when Model.Loaded =>
               Write
                 (Into, First, Place.Column + 1, Place.Width - 1, Unbounded.To_String (Text.Empty),
                  Colors (Muted_Role));
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
               Style     : Screen.Style := Entry_Style (Colors, Shown);
               Size_Text : constant String :=
                 (if Active and then Shown.Kind = Listing.Regular_Entry and then Shown.Status.Available
                    and then Place.Width >= Min_Size_Column_Width
                  then Format.Size_Image (Shown.Status.Size)
                  else "");
               Line      : constant Positive := First + Row;
               Name_Room : constant Natural :=
                 (if Size_Text'Length > 0 then Place.Width - Size_Text'Length - 3 else Place.Width - 2);
            begin
               if Model.Is_Marked (Item, Unbounded.To_String (Shown.Name)) then
                  Style := Overlay (Style, Colors (Marked_Role));
               end if;

               if I = Item.Cursor then
                  Style := Overlay (Style, Colors (if Active then Cursor_Role else Inactive_Cursor_Role));
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
      Width   : constant Natural :=
        Natural'Min
          (Columns, Natural'Max (Min_Panel_Width, Columns * Panel_Share_Numerator / Panel_Share_Denominator));
      Left    : constant Positive := (Columns - Width) / 2 + 1;
      Lines   : constant Natural := Natural (Context.Panel_Lines.Length);
      Height  : constant Natural := Natural'Min (Shape.Height, Lines + 1);
      Top     : constant Positive := Shape.First_Row;
      Panel   : constant Screen.Style := Context.Colors (Panel_Role);
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
              (if Line = Context.Panel_Cursor then Overlay (Panel, Context.Colors (Cursor_Role)) else Panel);
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
      Style   : Screen.Style := Context.Colors (Status_Role);

      --  A prompt, a question or a message keeps all the room it needs; the
      --  selected entry's details give way to the right side instead.
      Details : Boolean := False;
   begin
      if Context.Prompting then
         Left := Unbounded.To_Unbounded_String
           (" " & Unbounded.To_String (Context.Prompt_Label) & ": " & Unbounded.To_String (Context.Prompt_Text) & "_");
      elsif Unbounded.Length (Context.Question) > 0 then
         Left := " " & Context.Question;
         Style := Context.Colors (Alert_Role);
      elsif Context.Editing then
         Left := Unbounded.To_Unbounded_String (" " & Unbounded.To_String (Context.Text.Filter) & ": " & Filter & "_");
      elsif Unbounded.Length (Context.Message) > 0 then
         Left := " " & Context.Message;
         Style := (if Context.Message_Is_Error then Context.Colors (Alert_Role) else Context.Colors (Status_Role));
      elsif Model.Has_Selection (Current) then
         declare
            Item : constant Listing.Listed_Entry := Model.Selected (Current);
         begin
            Details := True;
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

      Screen.Fill (Into, Row, 1, Columns, Context.Colors (Status_Role));

      declare
         Right_Width : constant Natural := Screen.Width_Of (Right);
         Shown_Right : constant Boolean :=
           Right_Width < Columns
           and then (Details or else Right_Width + Screen.Width_Of (Unbounded.To_String (Left)) < Columns);
      begin
         Write
           (Into, Row, 1, (if Shown_Right then Columns - Right_Width - 1 else Columns), Unbounded.To_String (Left),
            Style);

         if Shown_Right then
            Write (Into, Row, Columns - Right_Width + 1, Right_Width, Right, Context.Colors (Status_Role));
         end if;
      end;
   end Draw_Status;

   function Entry_Style (Colors : Themes.Theme; Item : Listing.Listed_Entry) return Screen.Style is
   begin
      case Item.Kind is
         when Listing.Directory_Entry =>
            return Colors (Directory_Role);
         when Listing.Missing_Entry =>
            return Colors (Missing_Role);
         when Listing.FIFO_Entry | Listing.Character_Device_Entry | Listing.Block_Device_Entry
            | Listing.Socket_Entry | Listing.Other_Entry
         =>
            return Colors (Warning_Role);
         when Listing.Regular_Entry =>
            if Item.Is_Link then
               return Colors (Link_Role);
            elsif Item.Status.Available and then Owner_Can_Execute (Item.Status.Mode) then
               return Colors (Success_Role);
            else
               return Screen.Plain;
            end if;
      end case;
   end Entry_Style;

   function Layout_For (Rows, Columns : Natural) return Layout is
      Result : Layout;
      Gap    : constant := 1;
   begin
      Result.Height := (if Rows >= 3 then Rows - 2 else 0);

      if Columns >= Three_Pane_Columns then
         declare
            Parent_Width  : constant Natural := Columns / 8;
            Current_Width : constant Natural := Columns / 2;
         begin
            Result.Places (Model.Parent_Pane) := (True, 1, Parent_Width);
            Result.Places (Model.Current_Pane) := (True, Parent_Width + Gap + 1, Current_Width);
            Result.Places (Model.Preview_Pane) :=
              (True, Parent_Width + Current_Width + 2 * Gap + 1, Columns - Parent_Width - Current_Width - 2 * Gap);
         end;
      elsif Columns >= Two_Pane_Columns then
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

   function Listed_Heights (Browser : Model.Browser; Rows, Columns : Natural) return Model.Pane_Heights is
      Shape  : constant Layout := Layout_For (Rows, Columns);
      Result : Model.Pane_Heights := [others => 0];
   begin
      if Rows < Min_Rows or else Columns < Min_Columns then
         return Result;
      end if;

      for Kind in Model.Pane_Kind loop
         if Shape.Places (Kind).Shown
           and then Shape.Places (Kind).Width > 0
           and then not (Kind = Model.Preview_Pane and then Shows_Details (Browser))
         then
            Result (Kind) := Shape.Height;
         end if;
      end loop;

      return Result;
   end Listed_Heights;

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
