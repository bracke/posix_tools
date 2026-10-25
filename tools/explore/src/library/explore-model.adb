with Ada.Strings.Fixed;
with Explore.Paths;

package body Explore.Model is

   package Paths renames Explore.Paths;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Listing.Entry_Kind;
   use type Unbounded.Unbounded_String;

   --  The position in Item.Shown of the entry called Name, or zero.
   function Find (Item : Pane; Name : String) return Natural;

   function Next_Generation (Self : in out Browser) return Natural;

   --  Remember Path as a directory visited, for Go_Back.
   procedure Note_Visit (Self : in out Browser; Path : String);

   --  Recompute Item.Shown from Item.Entries, filtered by Filter when it is
   --  not empty, and put the cursor on Keep when it is still shown or as near
   --  Near as the entries allow.
   procedure Show (Item : in out Pane; Filter : String; Keep : String; Near : Natural);

   --  Mark the entries between the visual anchor and the cursor.
   procedure Update_Visual (Self : in out Browser);

   function Can_Enter (Self : Browser) return Boolean is
     (Has_Selection (Self.Panes (Current_Pane))
      and then Selected (Self.Panes (Current_Pane)).Kind = Listing.Directory_Entry);

   function Can_Leave (Self : Browser) return Boolean is
     (Self.Panes (Current_Pane).Is_Search
      or else (Unbounded.Length (Self.Panes (Current_Pane).Path) > 0
               and then Unbounded.To_String (Self.Panes (Current_Pane).Path) /= "/"));

   --  A pane for Path, waiting for its first entries.
   function New_Pane (Self : in out Browser; Path : String) return Pane is
     ((Path       => Unbounded.To_Unbounded_String (Path),
       State      => Loading,
       Generation => Next_Generation (Self),
       Pending    => True,
       others     => <>));

   function Selected (Item : Pane) return Listing.Listed_Entry is (Shown_Entry (Item, Item.Cursor));

   function Selected_Name (Item : Pane) return String is
     (if Has_Selection (Item) then Unbounded.To_String (Selected (Item).Name) else "");

   function Selected_Path (Item : Pane) return String is
     (if Has_Selection (Item) then Paths.Child_Of (Unbounded.To_String (Item.Path), Selected_Name (Item)) else "");

   function Shown_Entry (Item : Pane; I : Positive) return Listing.Listed_Entry is
     (Item.Entries (Item.Shown (I)));
   procedure Add_Results
     (Self       : in out Browser;
      Generation : Natural;
      Found      : Listing.Entry_Vectors.Vector;
      Finished   : Boolean)
   is
      Current : Pane renames Self.Panes (Current_Pane);
   begin
      if not Current.Is_Search or else Current.Generation /= Generation then
         return;
      end if;

      Current.Entries.Append (Found);
      Show (Current, Unbounded.To_String (Self.Filter), Selected_Name (Current), Current.Cursor);

      if Finished then
         Current.State := Loaded;
      end if;
   end Add_Results;

   procedure Apply_Filter (Self : in out Browser) is
      Current : Pane renames Self.Panes (Current_Pane);
   begin
      Show (Current, Unbounded.To_String (Self.Filter), Selected_Name (Current), Current.Cursor);
   end Apply_Filter;

   procedure Begin_Search
     (Self       : in out Browser;
      Root       : String;
      Label      : String;
      Contents   : Boolean;
      Generation : out Natural)
   is
   begin
      End_Visual (Self);
      Clear_Marks (Self);
      Self.Filter := Unbounded.Null_Unbounded_String;
      Note_Visit (Self, Unbounded.To_String (Self.Panes (Current_Pane).Path));
      Generation := Next_Generation (Self);
      Self.Panes (Current_Pane) :=
        (Path       => Unbounded.To_Unbounded_String (Root),
         State      => Loading,
         Generation => Generation,
         Is_Search  => True,
         others     => <>);
      Self.Search_Label := Unbounded.To_Unbounded_String (Label);
      Self.Search_Contents := Contents;
      Self.Search_Wanted := True;
      --  Beside the results, the directory they were found in.
      Self.Panes (Parent_Pane) := New_Pane (Self, Root);
      Self.Panes (Preview_Pane) := (others => <>);
   end Begin_Search;

   procedure Clear_Marks (Self : in out Browser) is
   begin
      Self.Panes (Current_Pane).Marked.Clear;
   end Clear_Marks;

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

   procedure End_Visual (Self : in out Browser) is
   begin
      Self.Visual := False;
      Self.Visual_Anchor := Unbounded.Null_Unbounded_String;
      Self.Visual_Base.Clear;
   end End_Visual;

   procedure Enter (Self : in out Browser) is
   begin
      if not Can_Enter (Self) then
         return;
      end if;

      --  Marks belong to the directory they were made in.
      End_Visual (Self);
      Clear_Marks (Self);
      Note_Visit (Self, Unbounded.To_String (Self.Panes (Current_Pane).Path));

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

   procedure Go_Back (Self : in out Browser) is
   begin
      if not Self.Back.Is_Empty then
         declare
            Target : constant String := Self.Back.Last_Element;
            Left   : constant String := Unbounded.To_String (Self.Panes (Current_Pane).Path);
         begin
            Self.Back.Delete_Last;
            Self.Forward.Append (Left);
            Open (Self, Target);
            --  Back in a parent, the cursor goes to the directory left.
            Self.Panes (Current_Pane).Wanted :=
              Unbounded.To_Unbounded_String (if Paths.Parent_Of (Left) = Target then Paths.Name_Of (Left) else "");
         end;
      end if;
   end Go_Back;

   procedure Go_Forward (Self : in out Browser) is
   begin
      if not Self.Forward.Is_Empty then
         declare
            Target : constant String := Self.Forward.Last_Element;
         begin
            Self.Forward.Delete_Last;
            Self.Back.Append (Unbounded.To_String (Self.Panes (Current_Pane).Path));
            Open (Self, Target);
         end;
      end if;
   end Go_Forward;

   procedure Jump (Self : in out Browser; Path : String; Wanted : String := "") is
   begin
      if Path /= Unbounded.To_String (Self.Panes (Current_Pane).Path) then
         Note_Visit (Self, Unbounded.To_String (Self.Panes (Current_Pane).Path));
         Open (Self, Path);
      end if;

      Self.Panes (Current_Pane).Wanted := Unbounded.To_Unbounded_String (Wanted);

      --  Already there: the cursor goes to Wanted at once, if it is shown.
      if Wanted'Length > 0 and then not Self.Panes (Current_Pane).Pending then
         declare
            Found : constant Natural := Find (Self.Panes (Current_Pane), Wanted);
         begin
            if Found > 0 then
               Self.Panes (Current_Pane).Cursor := Found;
            end if;
         end;
      end if;
   end Jump;

   procedure Leave (Self : in out Browser) is
   begin
      if not Can_Leave (Self) then
         return;
      end if;

      --  Marks belong to the directory they were made in.
      End_Visual (Self);
      Clear_Marks (Self);
      Note_Visit (Self, Unbounded.To_String (Self.Panes (Current_Pane).Path));

      --  Leaving search results goes back to the directory searched.
      if Self.Panes (Current_Pane).Is_Search then
         Open (Self, Unbounded.To_String (Self.Panes (Current_Pane).Path));
         return;
      end if;

      declare
         Left   : constant String := Unbounded.To_String (Self.Panes (Current_Pane).Path);
         Parent : constant String := Paths.Parent_Of (Left);
      begin
         Self.Filter := Unbounded.Null_Unbounded_String;
         Self.Panes (Preview_Pane) := Self.Panes (Current_Pane);
         Show (Self.Panes (Preview_Pane), "", Selected_Name (Self.Panes (Preview_Pane)), 0);

         if Self.Panes (Parent_Pane).Path = Parent and then Self.Panes (Parent_Pane).State in Loaded | Failed then
            Self.Panes (Current_Pane) := Self.Panes (Parent_Pane);
            Show (Self.Panes (Current_Pane), "", Paths.Name_Of (Left), 0);
         else
            Self.Panes (Current_Pane) := New_Pane (Self, Parent);
            Self.Panes (Current_Pane).Wanted := Unbounded.To_Unbounded_String (Paths.Name_Of (Left));
         end if;

         if Parent = "/" then
            Self.Panes (Parent_Pane) := (others => <>);
         else
            Self.Panes (Parent_Pane) := New_Pane (Self, Paths.Parent_Of (Parent));
            Self.Panes (Parent_Pane).Wanted := Unbounded.To_Unbounded_String (Paths.Name_Of (Parent));
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

      if In_Visual (Self) then
         Update_Visual (Self);
      end if;
   end Move_To;

   function Next_Generation (Self : in out Browser) return Natural is
   begin
      Self.Last_Generation := Self.Last_Generation + 1;
      return Self.Last_Generation;
   end Next_Generation;

   procedure Note_Visit (Self : in out Browser; Path : String) is
   begin
      if Path'Length = 0 then
         return;
      end if;

      Self.Back.Append (Path);

      if Natural (Self.Back.Length) > Max_History then
         Self.Back.Delete_First;
      end if;

      Self.Forward.Clear;
   end Note_Visit;

   procedure Open (Self : in out Browser; Path : String) is
   begin
      End_Visual (Self);
      Self.Filter := Unbounded.Null_Unbounded_String;
      Self.Panes (Current_Pane) := New_Pane (Self, Path);
      Self.Panes (Preview_Pane) := (others => <>);

      if Path = "/" then
         Self.Panes (Parent_Pane) := (others => <>);
      else
         Self.Panes (Parent_Pane) := New_Pane (Self, Paths.Parent_Of (Path));
         Self.Panes (Parent_Pane).Wanted := Unbounded.To_Unbounded_String (Paths.Name_Of (Path));
      end if;
   end Open;

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
      if Item.State /= Empty and then not Item.Is_Search then
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

   procedure Resume_Search (Self : in out Browser) is
      Current : Pane renames Self.Panes (Current_Pane);
   begin
      if Current.Is_Search and then Current.State = Loading then
         End_Visual (Self);
         Current.Entries.Clear;
         Current.Shown.Clear;
         Current.Marked.Clear;
         Current.Cursor := 0;
         Current.Top := 1;
         Current.Generation := Next_Generation (Self);
         Self.Search_Wanted := True;
      end if;
   end Resume_Search;

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

   procedure Scroll_Panes (Self : in out Browser; Heights : Pane_Heights) is
   begin
      for Kind in Pane_Kind loop
         if Heights (Kind) > 0 then
            Scroll (Self.Panes (Kind), Heights (Kind));
         end if;
      end loop;
   end Scroll_Panes;

   procedure Show (Item : in out Pane; Filter : String; Keep : String; Near : Natural) is
      Needle : constant String := Paths.Folded (Filter);
   begin
      Item.Shown.Clear;

      for I in 1 .. Natural (Item.Entries.Length) loop
         if Needle'Length = 0
           or else Ada.Strings.Fixed.Index (Paths.Folded (Unbounded.To_String (Item.Entries (I).Name)), Needle) > 0
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

   procedure Start_Visual (Self : in out Browser) is
      Current : Pane renames Self.Panes (Current_Pane);
   begin
      if Has_Selection (Current) then
         Self.Visual := True;
         Self.Visual_Anchor := Unbounded.To_Unbounded_String (Selected_Name (Current));
         Self.Visual_Base := Current.Marked;
         Update_Visual (Self);
      end if;
   end Start_Visual;

   function Targets (Self : Browser) return Explore.String_Vectors.Vector is
      Current : Pane renames Self.Panes (Current_Pane);
      Result  : Explore.String_Vectors.Vector;
   begin
      for Item of Current.Entries loop
         if Current.Marked.Contains (Unbounded.To_String (Item.Name)) then
            Result.Append (Paths.Child_Of (Unbounded.To_String (Current.Path), Unbounded.To_String (Item.Name)));
         end if;
      end loop;

      if Result.Is_Empty and then Has_Selection (Current) then
         Result.Append (Selected_Path (Current));
      end if;

      return Result;
   end Targets;

   procedure Toggle_Mark (Self : in out Browser) is
      Current : Pane renames Self.Panes (Current_Pane);
   begin
      if Has_Selection (Current) then
         declare
            Name : constant String := Selected_Name (Current);
         begin
            if Current.Marked.Contains (Name) then
               Current.Marked.Delete (Name);
            else
               Current.Marked.Insert (Name);
            end if;
         end;
      end if;
   end Toggle_Mark;

   procedure Update_Visual (Self : in out Browser) is
      Current : Pane renames Self.Panes (Current_Pane);
      --  The anchor's entry where it is now; left out by the filter, or gone,
      --  the selection runs from the cursor alone.
      Found   : constant Natural := Find (Current, Unbounded.To_String (Self.Visual_Anchor));
      Anchor  : constant Natural := (if Found > 0 then Found else Current.Cursor);
   begin
      Current.Marked := Self.Visual_Base;

      if Current.Cursor = 0 then
         return;
      end if;

      for I in Natural'Min (Anchor, Current.Cursor) .. Natural'Max (Anchor, Current.Cursor) loop
         Current.Marked.Include (Unbounded.To_String (Shown_Entry (Current, I).Name));
      end loop;
   end Update_Visual;

end Explore.Model;
