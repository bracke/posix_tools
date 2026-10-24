with Ada.Strings.Fixed;

package body Explore.Model is
   package Unbounded renames Ada.Strings.Unbounded;

   use type Listing.Entry_Kind;
   use type Unbounded.Unbounded_String;

   function Folded (Text : String) return String is
     ([for C of Text => (if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C)]);

   --  The position in Item.Shown of the entry called Name, or zero.
   function Find (Item : Pane; Name : String) return Natural;

   --  A pane for Path, waiting for its first entries.
   function New_Pane (Self : in out Browser; Path : String) return Pane;

   function Next_Generation (Self : in out Browser) return Natural;

   --  Recompute Item.Shown from Item.Entries, filtered by Filter when it is
   --  not empty, and put the cursor on Keep when it is still shown or as near
   --  Near as the entries allow.
   procedure Show (Item : in out Pane; Filter : String; Keep : String; Near : Natural);

   procedure Apply_Filter (Self : in out Browser) is
      Current : Pane renames Self.Panes (Current_Pane);
   begin
      Show (Current, Unbounded.To_String (Self.Filter), Selected_Name (Current), Current.Cursor);
   end Apply_Filter;

   function Can_Enter (Self : Browser) return Boolean is
     (Has_Selection (Self.Panes (Current_Pane))
      and then Selected (Self.Panes (Current_Pane)).Kind = Listing.Directory_Entry);

   function Can_Leave (Self : Browser) return Boolean is
     (Unbounded.Length (Self.Panes (Current_Pane).Path) > 0
      and then Unbounded.To_String (Self.Panes (Current_Pane).Path) /= "/");

   function Child_Of (Directory, Name : String) return String is
     (if Directory'Length > 0 and then Directory (Directory'Last) = '/'
      then Directory & Name
      else Directory & "/" & Name);

   procedure Deliver
     (Self       : in out Browser;
      Kind       : Pane_Kind;
      Generation : Natural;
      Entries    : Listing.Entry_Vectors.Vector;
      Readable   : Boolean)
   is
      Item : Pane renames Self.Panes (Kind);
   begin
      if not Item.Pending or else Item.Generation /= Generation then
         return;
      end if;

      declare
         Keep : constant String :=
           (if Unbounded.Length (Item.Wanted) > 0 then Unbounded.To_String (Item.Wanted)
            else Selected_Name (Item));
         Near : constant Natural := Item.Cursor;
      begin
         Item.Pending := False;
         Item.Wanted := Unbounded.Null_Unbounded_String;
         Item.Entries := Entries;
         Item.State := (if Readable then Loaded else Failed);
         Show (Item, (if Kind = Current_Pane then Unbounded.To_String (Self.Filter) else ""), Keep, Near);
      end;
   end Deliver;

   procedure Enter (Self : in out Browser) is
   begin
      if not Can_Enter (Self) then
         return;
      end if;

      declare
         Target : constant String := Selected_Path (Self.Panes (Current_Pane));
      begin
         Self.Filter := Unbounded.Null_Unbounded_String;
         Self.Panes (Parent_Pane) := Self.Panes (Current_Pane);
         Show (Self.Panes (Parent_Pane), "", Selected_Name (Self.Panes (Parent_Pane)), 0);

         if Self.Panes (Preview_Pane).Path = Target
           and then Self.Panes (Preview_Pane).State in Loaded | Failed
         then
            Self.Panes (Current_Pane) := Self.Panes (Preview_Pane);
         else
            Self.Panes (Current_Pane) := New_Pane (Self, Target);
         end if;

         Self.Panes (Preview_Pane) := (others => <>);
      end;
   end Enter;

   function Find (Item : Pane; Name : String) return Natural is
   begin
      if Name'Length = 0 then
         return 0;
      end if;

      for I in 1 .. Shown_Count (Item) loop
         if Unbounded.To_String (Shown_Entry (Item, I).Name) = Name then
            return I;
         end if;
      end loop;

      return 0;
   end Find;

   procedure Leave (Self : in out Browser) is
   begin
      if not Can_Leave (Self) then
         return;
      end if;

      declare
         Left   : constant String := Unbounded.To_String (Self.Panes (Current_Pane).Path);
         Parent : constant String := Parent_Of (Left);
      begin
         Self.Filter := Unbounded.Null_Unbounded_String;
         Self.Panes (Preview_Pane) := Self.Panes (Current_Pane);
         Show (Self.Panes (Preview_Pane), "", Selected_Name (Self.Panes (Preview_Pane)), 0);

         if Self.Panes (Parent_Pane).Path = Parent and then Self.Panes (Parent_Pane).State in Loaded | Failed then
            Self.Panes (Current_Pane) := Self.Panes (Parent_Pane);
            Show (Self.Panes (Current_Pane), "", Name_Of (Left), 0);
         else
            Self.Panes (Current_Pane) := New_Pane (Self, Parent);
            Self.Panes (Current_Pane).Wanted := Unbounded.To_Unbounded_String (Name_Of (Left));
         end if;

         if Parent = "/" then
            Self.Panes (Parent_Pane) := (others => <>);
         else
            Self.Panes (Parent_Pane) := New_Pane (Self, Parent_Of (Parent));
            Self.Panes (Parent_Pane).Wanted := Unbounded.To_Unbounded_String (Name_Of (Parent));
         end if;
      end;
   end Leave;

   procedure Move (Self : in out Browser; Offset : Integer) is
      Current : Pane renames Self.Panes (Current_Pane);
   begin
      if Shown_Count (Current) = 0 then
         return;
      end if;

      Move_To (Self, Natural (Integer'Max (1, Integer'Min (Shown_Count (Current), Current.Cursor + Offset))));
   end Move;

   procedure Move_To (Self : in out Browser; I : Natural) is
      Current : Pane renames Self.Panes (Current_Pane);
   begin
      Current.Cursor :=
        (if Shown_Count (Current) = 0 then 0 else Natural'Max (1, Natural'Min (I, Shown_Count (Current))));
   end Move_To;

   function Name_Of (Path : String) return String is
      Last : Natural := Path'Last;
   begin
      while Last >= Path'First and then Path (Last) = '/' loop
         Last := Last - 1;
      end loop;

      for I in reverse Path'First .. Last loop
         if Path (I) = '/' then
            return Path (I + 1 .. Last);
         end if;
      end loop;

      return Path (Path'First .. Last);
   end Name_Of;

   function New_Pane (Self : in out Browser; Path : String) return Pane is
     ((Path       => Unbounded.To_Unbounded_String (Path),
       State      => Loading,
       Generation => Next_Generation (Self),
       Pending    => True,
       others     => <>));

   function Next_Generation (Self : in out Browser) return Natural is
   begin
      Self.Last_Generation := Self.Last_Generation + 1;
      return Self.Last_Generation;
   end Next_Generation;

   procedure Open (Self : in out Browser; Path : String) is
   begin
      Self.Filter := Unbounded.Null_Unbounded_String;
      Self.Panes (Current_Pane) := New_Pane (Self, Path);
      Self.Panes (Preview_Pane) := (others => <>);

      if Path = "/" then
         Self.Panes (Parent_Pane) := (others => <>);
      else
         Self.Panes (Parent_Pane) := New_Pane (Self, Parent_Of (Path));
         Self.Panes (Parent_Pane).Wanted := Unbounded.To_Unbounded_String (Name_Of (Path));
      end if;
   end Open;

   function Parent_Of (Path : String) return String is
      Last : Natural := Path'Last;
   begin
      while Last > Path'First and then Path (Last) = '/' loop
         Last := Last - 1;
      end loop;

      for I in reverse Path'First .. Last loop
         if Path (I) = '/' then
            return (if I = Path'First then "/" else Path (Path'First .. I - 1));
         end if;
      end loop;

      return Path;
   end Parent_Of;

   function Preview_Changed (Self : in out Browser) return Boolean is
      Current : Pane renames Self.Panes (Current_Pane);
      Target  : constant String := Selected_Path (Current);
   begin
      if Unbounded.To_String (Self.Panes (Preview_Pane).Path) = Target then
         return False;
      elsif Can_Enter (Self) then
         Self.Panes (Preview_Pane) := New_Pane (Self, Target);
         return True;
      else
         --  Not a directory: the preview has nothing to list.
         Self.Panes (Preview_Pane) := (Path => Unbounded.To_Unbounded_String (Target), others => <>);
         return False;
      end if;
   end Preview_Changed;

   procedure Reload (Self : in out Browser; Kind : Pane_Kind) is
      Item : Pane renames Self.Panes (Kind);
   begin
      if Item.State /= Empty then
         Item.Generation := Next_Generation (Self);
         Item.Pending := True;
      end if;
   end Reload;

   procedure Reload_All (Self : in out Browser) is
   begin
      for Kind in Pane_Kind loop
         Reload (Self, Kind);
      end loop;
   end Reload_All;

   procedure Scroll (Item : in out Pane; Height : Positive) is
      Count : constant Natural := Shown_Count (Item);
   begin
      if Item.Cursor = 0 then
         Item.Top := 1;
         return;
      end if;

      if Item.Cursor < Item.Top then
         Item.Top := Item.Cursor;
      elsif Item.Cursor >= Item.Top + Height then
         Item.Top := Item.Cursor - Height + 1;
      end if;

      --  Never leave rows empty at the bottom that entries could fill.
      if Count >= Height and then Item.Top > Count - Height + 1 then
         Item.Top := Count - Height + 1;
      elsif Count < Height then
         Item.Top := 1;
      end if;
   end Scroll;

   function Selected (Item : Pane) return Listing.Listed_Entry is (Shown_Entry (Item, Item.Cursor));

   function Selected_Name (Item : Pane) return String is
     (if Has_Selection (Item) then Unbounded.To_String (Selected (Item).Name) else "");

   function Selected_Path (Item : Pane) return String is
     (if Has_Selection (Item) then Child_Of (Unbounded.To_String (Item.Path), Selected_Name (Item)) else "");

   procedure Show (Item : in out Pane; Filter : String; Keep : String; Near : Natural) is
      Needle : constant String := Folded (Filter);
   begin
      Item.Shown.Clear;

      for I in 1 .. Natural (Item.Entries.Length) loop
         if Needle'Length = 0
           or else Ada.Strings.Fixed.Index (Folded (Unbounded.To_String (Item.Entries (I).Name)), Needle) > 0
         then
            Item.Shown.Append (I);
         end if;
      end loop;

      declare
         Found : constant Natural := Find (Item, Keep);
      begin
         if Found > 0 then
            Item.Cursor := Found;
         elsif Shown_Count (Item) = 0 then
            Item.Cursor := 0;
         else
            Item.Cursor := Natural'Max (1, Natural'Min (Near, Shown_Count (Item)));
         end if;
      end;
   end Show;

   function Shown_Entry (Item : Pane; I : Positive) return Listing.Listed_Entry is
     (Item.Entries (Item.Shown (I)));
end Explore.Model;
