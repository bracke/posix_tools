with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Explore.String_Vectors;
with Posix_Tools.File_Operations.Listing;

--  What explore is showing, as data: the directory being browsed, its parent,
--  and the preview of the highlighted entry, each a pane with its entries and
--  cursor. Nothing here touches the filesystem or the terminal; directories
--  are read elsewhere and their entries handed in.
package Explore.Model is
   package Listing renames Posix_Tools.File_Operations.Listing;

   type Pane_State is
     (Empty,     --  Nothing to show.
      Loading,   --  Waiting for its entries.
      Loaded,    --  Showing its entries.
      Failed);   --  Its directory could not be read.

   package Index_Vectors is new Ada.Containers.Vectors (Positive, Positive);
   package Name_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);

   type Pane is record
      Path       : Ada.Strings.Unbounded.Unbounded_String;
      State      : Pane_State := Empty;
      --  Every entry read, in sort order.
      Entries    : Listing.Entry_Vectors.Vector;
      --  The positions in Entries of those the filter lets through.
      Shown      : Index_Vectors.Vector;
      --  The highlighted one of Shown; zero when Shown is empty.
      Cursor     : Natural := 0;
      --  The first of Shown on screen.
      Top        : Positive := 1;
      --  Unique to each request for new entries; entries read for any other
      --  arrive too late and are dropped.
      Generation : Natural := 0;
      --  Entries have been asked for and not yet delivered. What the pane
      --  showed before stays shown meanwhile.
      Pending    : Boolean := False;
      --  The name to put the cursor on once entries arrive.
      Wanted     : Ada.Strings.Unbounded.Unbounded_String;
      --  Names marked for an operation.
      Marked     : Name_Sets.Set;
      --  The pane holds search results, each named by its path below Path,
      --  instead of a directory's entries; it is never read again.
      Is_Search  : Boolean := False;
   end record;

   type Pane_Kind is (Parent_Pane, Current_Pane, Preview_Pane);

   type Pane_Set is array (Pane_Kind) of Pane;

   type Browser is record
      Panes       : Pane_Set;
      Show_Hidden : Boolean := False;
      Order       : Listing.Sort_Order;
      --  Entries of the current pane whose names do not contain this, folding
      --  ASCII case, are not shown.
      Filter      : Ada.Strings.Unbounded.Unbounded_String;
      --  The last generation handed out.
      Last_Generation : Natural := 0;
      --  Directories visited before the current one, the latest last, and
      --  those gone back from, the latest last.
      Back        : Explore.String_Vectors.Vector;
      Forward     : Explore.String_Vectors.Vector;
      --  Visual selection: the entry it started on, zero when it is off,
      --  and the marks there were before it started.
      Visual_Anchor : Natural := 0;
      Visual_Base   : Name_Sets.Set;
      --  What the search the current pane shows looks for.
      Search_Label  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  How many directories back history keeps.
   Max_History : constant := 100;

   function Shown_Count (Item : Pane) return Natural is (Natural (Item.Shown.Length));

   --  The I'th entry shown.
   function Shown_Entry (Item : Pane; I : Positive) return Listing.Listed_Entry
     with Pre => I <= Shown_Count (Item);

   function Has_Selection (Item : Pane) return Boolean is (Item.Cursor in 1 .. Shown_Count (Item));

   function Selected (Item : Pane) return Listing.Listed_Entry
     with Pre => Has_Selection (Item);

   function Selected_Name (Item : Pane) return String;

   --  The full path of the selected entry; empty when there is none.
   function Selected_Path (Item : Pane) return String;

   --  Start browsing Path afresh: every pane is reset and waits for entries.
   procedure Open (Self : in out Browser; Path : String);

   --  Open Path as a visit: the directory left is remembered for Go_Back,
   --  and what was gone back from is forgotten. Wanted names the entry to
   --  put the cursor on once the entries arrive.
   procedure Jump (Self : in out Browser; Path : String; Wanted : String := "");

   --  Return to the directory visited before, or to the one gone back from.
   procedure Go_Back (Self : in out Browser);
   procedure Go_Forward (Self : in out Browser);

   --  Start a visual selection at the cursor: moving then marks every entry
   --  between it and the cursor, on top of what was marked before.
   procedure Start_Visual (Self : in out Browser);

   --  End it, keeping its marks.
   procedure End_Visual (Self : in out Browser);

   function In_Visual (Self : Browser) return Boolean is (Self.Visual_Anchor > 0);

   --  Show the results of a search below Root in the current pane, as a
   --  visit, and return the generation the results must carry. Label says
   --  what is searched for.
   procedure Begin_Search (Self : in out Browser; Root, Label : String; Generation : out Natural);

   --  Add results found for Generation, the cursor staying on its entry;
   --  Finished says the search has ended.
   procedure Add_Results
     (Self       : in out Browser;
      Generation : Natural;
      Found      : Listing.Entry_Vectors.Vector;
      Finished   : Boolean);

   function Is_Searching (Self : Browser) return Boolean is (Self.Panes (Current_Pane).Is_Search);

   --  Ask for a pane's entries again, keeping what it shows until they come.
   procedure Reload (Self : in out Browser; Kind : Pane_Kind);

   --  Ask for every pane's entries again, as after the sort order or the
   --  hidden-file setting changed.
   procedure Reload_All (Self : in out Browser);

   --  The parent directory of an absolute Path; Path itself for the root.
   function Parent_Of (Path : String) return String;

   --  The last component of Path, any trailing slashes aside; empty for the
   --  root.
   function Name_Of (Path : String) return String;

   --  The path of Name in Directory, with one slash between them.
   function Child_Of (Directory, Name : String) return String;

   --  Text with its ASCII letters in lower case and every other byte as it
   --  is, as the filter and a name search compare names: a byte of a UTF-8
   --  sequence is never mistaken for a letter.
   function Folded (Text : String) return String;

   --  Hand a pane the entries read for Generation. Entries for any other
   --  generation are ignored. The cursor goes to the pane's wanted name, or
   --  stays on the name it was on, or as near its old place as the entries
   --  allow.
   procedure Deliver
     (Self       : in out Browser;
      Kind       : Pane_Kind;
      Generation : Natural;
      Entries    : Listing.Entry_Vectors.Vector;
      Readable   : Boolean);

   --  Move the current pane's cursor by Offset, stopping at either end.
   procedure Move (Self : in out Browser; Offset : Integer);

   --  Put the current pane's cursor on the I'th entry shown, or as near as it goes.
   procedure Move_To (Self : in out Browser; I : Natural);

   --  Keep the cursor of a pane within its Height rows on screen.
   procedure Scroll (Item : in out Pane; Height : Positive);

   --  The rows each pane lists its entries in, zero for one not listed.
   type Pane_Heights is array (Pane_Kind) of Natural;

   --  Scroll every pane listed to its height; one not listed keeps its place.
   procedure Scroll_Panes (Self : in out Browser; Heights : Pane_Heights);

   --  Whether the selected entry of the current pane is a directory to enter.
   function Can_Enter (Self : Browser) return Boolean;

   --  Make the selected directory the current one: the current pane becomes
   --  the parent, and the preview, if it already shows that directory, the
   --  current. Panes that changed are left Loading for their entries.
   procedure Enter (Self : in out Browser);

   --  Whether the current directory has a parent to go up to.
   function Can_Leave (Self : Browser) return Boolean;

   --  Go up to the parent: the parent pane becomes the current one, with the
   --  cursor on the directory just left, and the current the preview.
   procedure Leave (Self : in out Browser);

   --  Point the preview at the selected entry: a directory is listed, anything
   --  else leaves the pane empty. True when the preview needs new entries.
   function Preview_Changed (Self : in out Browser) return Boolean;

   --  Recompute what the current pane shows after the filter changed, keeping
   --  the cursor on the same entry where it is still shown.
   procedure Apply_Filter (Self : in out Browser);

   function Is_Marked (Item : Pane; Name : String) return Boolean is (Item.Marked.Contains (Name));

   --  Mark the selected entry of the current pane, or unmark it if it was.
   procedure Toggle_Mark (Self : in out Browser);

   procedure Clear_Marks (Self : in out Browser);

   --  What an operation acts on: the full paths of the marked entries of the
   --  current pane that are still there, or of the selected entry when none
   --  are marked.
   function Targets (Self : Browser) return Explore.String_Vectors.Vector;
end Explore.Model;
