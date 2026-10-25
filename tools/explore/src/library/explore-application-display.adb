with Explore.Image_Cache;
with Explore.Images;
with Explore.Keymap;
with Explore.Model;
with Explore.Previews;
with Explore.Protocol;
with Explore.Render;
with Explore.Screen;
with Explore.Tabs;
with Explore.Words;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Numeric_Images;

package body Explore.Application.Display is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Model renames Explore.Model;

   use type Explore.Model.Pane_State;
   use type Explore.Previews.Preview_Kind;

   function Image (Value : Natural) return String renames Posix_Tools.Text.Numeric_Images.Natural_Image;

   --  The name of user or group Id, looked up once and kept in Names.
   function Name_For (Names : in out Name_Maps.Map; Id : Natural; Group : Boolean) return String;

   procedure Draw (State : in out Session; Ok : out Boolean) is
      Current : Model.Pane renames State.Browser.Panes (Model.Current_Pane);
   begin
      Show_Mode (State);
      State.Frame.Prefix := Unbounded.To_Unbounded_String (Explore.Keymap.Pending (State.Interaction.Keys));
      State.Frame.Tab_Line := Unbounded.To_Unbounded_String (Explore.Tabs.Line (State.Tabs, State.Browser));
      State.Frame.Search_Line :=
        (if Model.Is_Searching (State.Browser)
         then Unbounded.To_Unbounded_String
                ((if Current.State = Model.Loading
                  then Unbounded.To_String (State.Config.Words.Searching) & " " else "")
                 & "'" & Unbounded.To_String (State.Browser.Search_Label) & "'")
         else Unbounded.Null_Unbounded_String);
      State.Frame.Owner := Unbounded.Null_Unbounded_String;

      if Model.Has_Selection (Current) and then Model.Selected (Current).Status.Available then
         declare
            Status : constant FS.Entry_Status := Model.Selected (Current).Status;
         begin
            State.Frame.Owner :=
              Unbounded.To_Unbounded_String
                (Name_For (State.Users, Status.User, Group => False) & ":"
                 & Name_For (State.Groups, Status.Group, Group => True));
         end;
      end if;

      Model.Scroll_Panes
        (State.Browser,
         Explore.Render.Listed_Heights
           (State.Browser,
            Explore.Screen.Rows (State.Terminal.Wanted),
            Explore.Screen.Columns (State.Terminal.Wanted)));
      Explore.Render.Draw (State.Terminal.Wanted, State.Browser, State.Frame);
      Ok := Write
        (Explore.Protocol.Begin_Frame
         & Explore.Screen.Diff_Output (State.Terminal.Shown, State.Terminal.Wanted, Full => State.Terminal.Repaint)
         & Explore.Protocol.End_Frame);
      State.Dirty := False;
      State.Terminal.Repaint := False;
   end Draw;

   procedure Fill_Panel (State : in out Session; Now : Explore.Jobs.Snapshot) is
   begin
      Explore.Words.Panel (State.Config.Words, Now, State.Frame.Panel_Lines, State.Frame.Panel_Ids);
      State.Frame.Panel_Cursor :=
        Natural'Max (1, Natural'Min (State.Frame.Panel_Cursor, Natural (State.Frame.Panel_Lines.Length)));
      State.Frame.Panel_Title := State.Config.Words.Jobs_Title;
      State.Dirty := True;
   end Fill_Panel;

   procedure Hide_Image (State : in out Session) is
   begin
      if State.Frame.Image_Id > 0 then
         State.Frame.Image_Id := 0;
         State.Dirty := True;
      end if;
   end Hide_Image;

   function Name_For (Names : in out Name_Maps.Map; Id : Natural; Group : Boolean) return String is
      Position : constant Name_Maps.Cursor := Names.Find (Id);
   begin
      if Name_Maps.Has_Element (Position) then
         return Unbounded.To_String (Name_Maps.Element (Position));
      end if;

      declare
         Found : constant String := (if Group then FS.Group_Name_For_Id (Id) else FS.User_Name_For_Id (Id));
         Name  : constant String := (if Found'Length > 0 then Found else Image (Id));
      begin
         Names.Insert (Id, Unbounded.To_Unbounded_String (Name));
         return Name;
      end;
   end Name_For;

   procedure Resize (State : in out Session; Rows, Columns : Natural) is
   begin
      State.Terminal.Size := (Rows => Rows, Columns => Columns);
      Explore.Screen.Resize (State.Terminal.Wanted, Rows, Columns);
      State.Terminal.Repaint := True;
      State.Dirty := True;

      --  The pane changed size; the image is placed afresh to fit it.
      if State.Frame.Image_Id > 0 then
         Show_Image (State);
      end if;
   end Resize;

   procedure Show_Image (State : in out Session) is
      use type Explore.Images.Image_Format;

      Preview : Explore.Previews.Preview renames State.Frame.Preview;
      Content : constant Explore.Render.Area :=
        Explore.Render.Content_Area (Explore.Render.Layout_For (State.Terminal.Size.Rows, State.Terminal.Size.Columns));
      Caps    : Explore.Protocol.Capability_Set renames State.Terminal.Identity.Capabilities;
      Columns, Rows : Positive;
      Id      : Positive;
   begin
      Hide_Image (State);

      if Preview.Kind /= Explore.Previews.Image_Preview
        or else not Caps (Explore.Protocol.Kitty_Graphics)
        or else (Preview.Format = Explore.Images.JPEG_Format and then not Caps (Explore.Protocol.Kitty_Graphics_JPEG))
        or else (Preview.Format = Explore.Images.GIF_Format and then not Caps (Explore.Protocol.Kitty_Graphics_GIF))
        or else Content.Rows = 0
        or else Content.Columns = 0
        or else Preview.Width = 0
        or else Preview.Height = 0
      then
         return;
      end if;

      Explore.Images.Fit
        (Preview.Width, Preview.Height, State.Terminal.Cell_Width, State.Terminal.Cell_Height,
         Natural'Min (Content.Columns, Explore.Images.Diacritic_Count),
         Natural'Min (Content.Rows, Explore.Images.Diacritic_Count),
         Columns, Rows);

      declare
         Output : constant String :=
           Explore.Image_Cache.Show
             (State.Terminal.Images,
              (Path => Preview.Path, Modified => Preview.Modified, Size => Preview.File_Size),
              Preview.Format,
              Preview.Image,
              Columns,
              Rows,
              State.Terminal.In_Tmux,
              Id);
      begin
         if Output'Length > 0 and then not Write (Output) then
            Lose_Terminal (State);
            return;
         end if;
      end;

      State.Frame.Image_Id := Id;
      State.Frame.Image_Columns := Columns;
      State.Frame.Image_Rows := Rows;
      State.Dirty := True;
   end Show_Image;
end Explore.Application.Display;
