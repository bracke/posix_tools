with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Strings.Unbounded;
with Explore.Input;
with Explore.Keymap;
with Explore.Model;
with Explore.Directory_Readers;
with Posix_Tools.File_Operations.Listing;

package body Model_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package Listing renames Posix_Tools.File_Operations.Listing;
   package Model renames Explore.Model;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Explore.Keymap.Action;
   use type Listing.Sort_Key;
   use type Model.Pane_Kind;
   use type Model.Pane_State;

   --  Entries named by Names, separated by spaces; a trailing '/' makes a
   --  directory.
   function Entries (Names : String) return Listing.Entry_Vectors.Vector;

   --  Deliver the entries a pane is waiting for.
   procedure Give (Browser : in out Model.Browser; Kind : Model.Pane_Kind; Names : String);

   function Path (Browser : Model.Browser; Kind : Model.Pane_Kind) return String is
     (Unbounded.To_String (Browser.Panes (Kind).Path));

   function Entries (Names : String) return Listing.Entry_Vectors.Vector is
      Result : Listing.Entry_Vectors.Vector;
      First  : Positive := Names'First;
   begin
      for I in Names'First .. Names'Last + 1 loop
         if I > Names'Last or else Names (I) = ' ' then
            if I > First then
               declare
                  Word      : constant String := Names (First .. I - 1);
                  Directory : constant Boolean := Word (Word'Last) = '/';
               begin
                  Result.Append
                    (Listing.Listed_Entry'
                       (Name =>
                        Unbounded.To_Unbounded_String
                          (if Directory then Word (Word'First .. Word'Last - 1) else Word),
                      Kind => (if Directory then Listing.Directory_Entry else Listing.Regular_Entry),
                      others => <>));
               end;
            end if;

            First := I + 1;
         end if;
      end loop;

      return Result;
   end Entries;

   procedure Give (Browser : in out Model.Browser; Kind : Model.Pane_Kind; Names : String) is
   begin
      Model.Deliver (Browser, Kind, Browser.Panes (Kind).Generation, Entries (Names), Readable => True);
   end Give;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("model:paths", Test_Paths'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("model:open and deliver", Test_Open_And_Deliver'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("model:stale entries dropped", Test_Stale_Entries_Dropped'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("model:enter and leave", Test_Enter_And_Leave'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("model:cursor and scroll", Test_Cursor_And_Scroll'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("model:filter", Test_Filter'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("model:history and visual", Test_History_And_Visual'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("keymap:bindings", Test_Keymap'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("directory_readers:board", Test_Board'Access));
      return Result;
   end Suite;

   procedure Test_Board (T : in out Fixture) is
      pragma Unreferenced (T);
      Readers : Explore.Directory_Readers.Board;
      Item    : Explore.Directory_Readers.Slot;
      Work    : Explore.Directory_Readers.Request;
      Closed  : Boolean;
      Outcome : Explore.Directory_Readers.Result;
      Found   : Boolean;
   begin
      AUnit.Assertions.Assert (not Readers.Busy, "idle at first");

      Readers.Submit (Model.Parent_Pane, (Generation => 1, others => <>));
      Readers.Submit (Model.Current_Pane, (Generation => 2, others => <>));
      Readers.Submit (Model.Current_Pane, (Generation => 3, others => <>));
      AUnit.Assertions.Assert (Readers.Busy, "busy with requests waiting");

      Readers.Take (Item, Work, Closed);
      AUnit.Assertions.Assert
        (not Closed and then Item = Model.Current_Pane and then Work.Generation = 3,
         "the current pane first, and only its newest request");
      AUnit.Assertions.Assert (not Readers.Is_Wanted (Model.Current_Pane, 2), "a replaced request is not wanted");

      Readers.Submit (Model.Current_Pane, (Generation => 4, others => <>));
      AUnit.Assertions.Assert (not Readers.Is_Wanted (Model.Current_Pane, 3), "the running one is replaced too");
      Readers.Finish (Model.Current_Pane, (Generation => 3, others => <>));
      Readers.Collect (Model.Current_Pane, Outcome, Found);
      AUnit.Assertions.Assert (not Found, "the result of a replaced request is dropped");

      Readers.Take (Item, Work, Closed);
      AUnit.Assertions.Assert (Item = Model.Current_Pane and then Work.Generation = 4, "the replacement");
      Readers.Finish (Model.Current_Pane, (Generation => 4, Readable => True, others => <>));
      Readers.Collect (Model.Current_Pane, Outcome, Found);
      AUnit.Assertions.Assert (Found and then Outcome.Generation = 4 and then Outcome.Readable, "collected");

      Readers.Take (Item, Work, Closed);
      AUnit.Assertions.Assert (Item = Model.Parent_Pane and then Work.Generation = 1, "then the parent");
      Readers.Finish (Model.Parent_Pane, (Generation => 1, others => <>));
      Readers.Collect (Model.Parent_Pane, Outcome, Found);
      AUnit.Assertions.Assert (not Readers.Busy, "idle once everything is collected");

      Readers.Shut_Down;
      Readers.Take (Item, Work, Closed);
      AUnit.Assertions.Assert (Closed, "a shut-down board tells its workers to end");
   end Test_Board;

   procedure Test_Cursor_And_Scroll (T : in out Fixture) is
      pragma Unreferenced (T);
      Browser : Model.Browser;
   begin
      Model.Open (Browser, "/d");
      Give (Browser, Model.Current_Pane, "a b c d e f g h i j");
      AUnit.Assertions.Assert (Browser.Panes (Model.Current_Pane).Cursor = 1, "the cursor starts at the top");

      Model.Move (Browser, -5);
      AUnit.Assertions.Assert (Browser.Panes (Model.Current_Pane).Cursor = 1, "it stops at the top");
      Model.Move (Browser, 100);
      AUnit.Assertions.Assert (Browser.Panes (Model.Current_Pane).Cursor = 10, "and at the bottom");

      Model.Scroll (Browser.Panes (Model.Current_Pane), 4);
      AUnit.Assertions.Assert (Browser.Panes (Model.Current_Pane).Top = 7, "scrolled to show the cursor");
      Model.Move_To (Browser, 5);
      Model.Scroll (Browser.Panes (Model.Current_Pane), 4);
      AUnit.Assertions.Assert (Browser.Panes (Model.Current_Pane).Top = 5, "scrolled back up to it");
      Model.Scroll (Browser.Panes (Model.Current_Pane), 20);
      AUnit.Assertions.Assert (Browser.Panes (Model.Current_Pane).Top = 1, "everything fits, nothing scrolled");

      Model.Move_To (Browser, 9);
      Model.Reload (Browser, Model.Current_Pane);
      Give (Browser, Model.Current_Pane, "a b c d e f g h i j k");
      AUnit.Assertions.Assert
        (Model.Selected_Name (Browser.Panes (Model.Current_Pane)) = "i", "a reload keeps the cursor on its name");
      Model.Reload (Browser, Model.Current_Pane);
      Give (Browser, Model.Current_Pane, "a b c");
      AUnit.Assertions.Assert
        (Browser.Panes (Model.Current_Pane).Cursor = 3, "or as near its place as the entries allow");
   end Test_Cursor_And_Scroll;

   procedure Test_Enter_And_Leave (T : in out Fixture) is
      pragma Unreferenced (T);
      Browser : Model.Browser;
   begin
      Model.Open (Browser, "/home/user");
      Give (Browser, Model.Current_Pane, "docs/ notes.txt");
      Give (Browser, Model.Parent_Pane, "other/ user/");

      AUnit.Assertions.Assert (Model.Preview_Changed (Browser), "the selected directory is previewed");
      AUnit.Assertions.Assert (Path (Browser, Model.Preview_Pane) = "/home/user/docs", "preview path");
      Give (Browser, Model.Preview_Pane, "a.md b.md");

      Model.Enter (Browser);
      AUnit.Assertions.Assert (Path (Browser, Model.Current_Pane) = "/home/user/docs", "entered");
      AUnit.Assertions.Assert
        (Browser.Panes (Model.Current_Pane).State = Model.Loaded
         and then not Browser.Panes (Model.Current_Pane).Pending,
         "the preview's entries are reused, nothing to read");
      AUnit.Assertions.Assert
        (Path (Browser, Model.Parent_Pane) = "/home/user"
         and then Model.Selected_Name (Browser.Panes (Model.Parent_Pane)) = "docs",
         "the parent is where we came from, its cursor on the directory entered");

      Model.Leave (Browser);
      AUnit.Assertions.Assert
        (Path (Browser, Model.Current_Pane) = "/home/user"
         and then Model.Selected_Name (Browser.Panes (Model.Current_Pane)) = "docs",
         "back up, on the directory left");
      AUnit.Assertions.Assert
        (Path (Browser, Model.Preview_Pane) = "/home/user/docs", "the directory left is the preview");
      AUnit.Assertions.Assert
        (Path (Browser, Model.Parent_Pane) = "/home" and then Browser.Panes (Model.Parent_Pane).Pending,
         "the new parent is read");

      Model.Move (Browser, 1);
      AUnit.Assertions.Assert (not Model.Can_Enter (Browser), "a file cannot be entered");
      AUnit.Assertions.Assert (not Model.Preview_Changed (Browser), "a file has nothing to list");
      AUnit.Assertions.Assert
        (Browser.Panes (Model.Preview_Pane).State = Model.Empty
         and then Path (Browser, Model.Preview_Pane) = "/home/user/notes.txt",
         "its preview is empty");

      Model.Open (Browser, "/");
      AUnit.Assertions.Assert
        (not Model.Can_Leave (Browser) and then Browser.Panes (Model.Parent_Pane).State = Model.Empty,
         "the root has no parent");
   end Test_Enter_And_Leave;

   procedure Test_History_And_Visual (T : in out Fixture) is
      pragma Unreferenced (T);
      Browser : Model.Browser;
   begin
      Model.Open (Browser, "/home/user");
      Give (Browser, Model.Current_Pane, "docs/ music/");
      Model.Enter (Browser);
      Give (Browser, Model.Current_Pane, "a.md");
      Model.Jump (Browser, "/etc", Wanted => "hosts");
      AUnit.Assertions.Assert (Path (Browser, Model.Current_Pane) = "/etc", "jumped");
      Give (Browser, Model.Current_Pane, "fstab hosts passwd");
      AUnit.Assertions.Assert
        (Model.Selected_Name (Browser.Panes (Model.Current_Pane)) = "hosts", "the cursor goes to the wanted entry");

      Model.Go_Back (Browser);
      AUnit.Assertions.Assert (Path (Browser, Model.Current_Pane) = "/home/user/docs", "back to where the jump left");
      Model.Go_Back (Browser);
      AUnit.Assertions.Assert (Path (Browser, Model.Current_Pane) = "/home/user", "back again");
      Give (Browser, Model.Current_Pane, "docs/ music/");
      AUnit.Assertions.Assert
        (Model.Selected_Name (Browser.Panes (Model.Current_Pane)) = "docs",
         "back in a parent, on the directory left");
      Model.Go_Forward (Browser);
      AUnit.Assertions.Assert (Path (Browser, Model.Current_Pane) = "/home/user/docs", "forward");
      Model.Go_Forward (Browser);
      Model.Go_Forward (Browser);
      AUnit.Assertions.Assert (Path (Browser, Model.Current_Pane) = "/etc", "forward to the end, and no further");

      Give (Browser, Model.Current_Pane, "a b c d e");
      Model.Move_To (Browser, 1);
      Model.Toggle_Mark (Browser);
      Model.Move_To (Browser, 3);
      Model.Start_Visual (Browser);
      Model.Move (Browser, 2);
      AUnit.Assertions.Assert
        (Natural (Browser.Panes (Model.Current_Pane).Marked.Length) = 4, "visual marks c to e on top of a");
      Model.Move (Browser, -1);
      AUnit.Assertions.Assert
        (not Model.Is_Marked (Browser.Panes (Model.Current_Pane), "e"), "moving back unmarks what it leaves");
      Model.End_Visual (Browser);
      Model.Move (Browser, -3);
      AUnit.Assertions.Assert
        (Natural (Browser.Panes (Model.Current_Pane).Marked.Length) = 3, "ended, the marks stay put");
   end Test_History_And_Visual;

   procedure Test_Filter (T : in out Fixture) is
      pragma Unreferenced (T);
      Browser : Model.Browser;
   begin
      Model.Open (Browser, "/d");
      Give (Browser, Model.Current_Pane, "Alpha beta gamma Delta");
      Model.Move_To (Browser, 3);

      Browser.Filter := Unbounded.To_Unbounded_String ("A");
      Model.Apply_Filter (Browser);
      AUnit.Assertions.Assert
        (Model.Shown_Count (Browser.Panes (Model.Current_Pane)) = 4, "case is ignored: every name has an a");
      Browser.Filter := Unbounded.To_Unbounded_String ("ta");
      Model.Apply_Filter (Browser);
      AUnit.Assertions.Assert (Model.Shown_Count (Browser.Panes (Model.Current_Pane)) = 2, "beta and Delta");
      AUnit.Assertions.Assert
        (Model.Selected_Name (Browser.Panes (Model.Current_Pane)) = "Delta", "the cursor stays near its place");
      Browser.Filter := Unbounded.To_Unbounded_String ("zzz");
      Model.Apply_Filter (Browser);
      AUnit.Assertions.Assert
        (not Model.Has_Selection (Browser.Panes (Model.Current_Pane)), "nothing shown, nothing selected");
      Browser.Filter := Unbounded.Null_Unbounded_String;
      Model.Apply_Filter (Browser);
      AUnit.Assertions.Assert (Model.Shown_Count (Browser.Panes (Model.Current_Pane)) = 4, "filter cleared");
   end Test_Filter;

   procedure Test_Keymap (T : in out Fixture) is
      pragma Unreferenced (T);
      Keys    : Explore.Keymap.State;
      Command : Explore.Keymap.Command;

      function Key (Code : Wide_Wide_Character) return Explore.Input.Event is
        ((Kind => Explore.Input.Key_Event, Key => Explore.Input.Character_Key, Code => Code, others => <>));
   begin
      Explore.Keymap.Translate (Keys, Key ('j'), Command);
      AUnit.Assertions.Assert (Command.Kind = Explore.Keymap.Move_Down, "j");
      Explore.Keymap.Translate (Keys, Key ('g'), Command);
      AUnit.Assertions.Assert
        (Command.Kind = Explore.Keymap.No_Action and then Explore.Keymap.Pending (Keys) = "g", "g waits");
      Explore.Keymap.Translate (Keys, Key ('g'), Command);
      AUnit.Assertions.Assert (Command.Kind = Explore.Keymap.Move_Top, "gg");
      Explore.Keymap.Translate (Keys, Key ('g'), Command);
      Explore.Keymap.Translate (Keys, Key ('x'), Command);
      AUnit.Assertions.Assert
        (Command.Kind = Explore.Keymap.No_Action and then Explore.Keymap.Pending (Keys) = "",
         "an unknown second key cancels the prefix");
      Explore.Keymap.Translate (Keys, Key (','), Command);
      Explore.Keymap.Translate (Keys, Key ('S'), Command);
      AUnit.Assertions.Assert
        (Command.Kind = Explore.Keymap.Sort_Entries and then Command.Key = Listing.By_Size and then Command.Descending,
         ",S sorts by size, largest first");
      Explore.Keymap.Translate
        (Keys, (Kind => Explore.Input.Key_Event, Key => Explore.Input.Character_Key, Code => 'd',
                Mods => (Control => True, others => False), others => <>), Command);
      AUnit.Assertions.Assert (Command.Kind = Explore.Keymap.Half_Page_Down, "Ctrl+d");
      Explore.Keymap.Translate
        (Keys, (Kind => Explore.Input.Key_Event, Key => Explore.Input.Left, others => <>), Command);
      AUnit.Assertions.Assert (Command.Kind = Explore.Keymap.Leave_Directory, "Left");
      Explore.Keymap.Translate (Keys, Key ('3'), Command);
      AUnit.Assertions.Assert
        (Command.Kind = Explore.Keymap.Switch_Tab and then Command.Number = 3, "a digit switches to that tab");
      Explore.Keymap.Translate (Keys, Key ('b'), Command);
      Explore.Keymap.Translate (Keys, Key ('q'), Command);
      AUnit.Assertions.Assert
        (Command.Kind = Explore.Keymap.Set_Bookmark and then Command.Letter = 'q', "bq sets bookmark q, not quit");
      Explore.Keymap.Translate (Keys, Key ('''), Command);
      Explore.Keymap.Translate (Keys, Key ('q'), Command);
      AUnit.Assertions.Assert
        (Command.Kind = Explore.Keymap.Go_Bookmark and then Command.Letter = 'q', "a quote and q go to it");
   end Test_Keymap;

   procedure Test_Open_And_Deliver (T : in out Fixture) is
      pragma Unreferenced (T);
      Browser : Model.Browser;
   begin
      Model.Open (Browser, "/home/user");
      AUnit.Assertions.Assert
        (Browser.Panes (Model.Current_Pane).State = Model.Loading
         and then Browser.Panes (Model.Current_Pane).Pending
         and then Browser.Panes (Model.Parent_Pane).Pending,
         "the current directory and its parent are waited for");
      AUnit.Assertions.Assert
        (Browser.Panes (Model.Current_Pane).Generation /= Browser.Panes (Model.Parent_Pane).Generation,
         "each request has a generation of its own");

      Give (Browser, Model.Parent_Pane, "aaa/ user/ zzz/");
      AUnit.Assertions.Assert
        (Model.Selected_Name (Browser.Panes (Model.Parent_Pane)) = "user",
         "the parent's cursor is on the directory being browsed");

      Model.Deliver
        (Browser, Model.Current_Pane, Browser.Panes (Model.Current_Pane).Generation, Entries (""), Readable => False);
      AUnit.Assertions.Assert (Browser.Panes (Model.Current_Pane).State = Model.Failed, "an unreadable directory");
   end Test_Open_And_Deliver;

   procedure Test_Paths (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert (Model.Parent_Of ("/a/b") = "/a", "parent");
      AUnit.Assertions.Assert (Model.Parent_Of ("/a") = "/", "parent of a top directory");
      AUnit.Assertions.Assert (Model.Parent_Of ("/") = "/", "the root is its own parent");
      AUnit.Assertions.Assert (Model.Name_Of ("/a/b") = "b", "name");
      AUnit.Assertions.Assert (Model.Name_Of ("/a/b/") = "b", "name, trailing slash");
      AUnit.Assertions.Assert (Model.Name_Of ("/") = "", "the root has no name");
      AUnit.Assertions.Assert (Model.Name_Of ("//") = "", "nor has the root written twice");
      AUnit.Assertions.Assert (Model.Name_Of ("/a//") = "a", "name, trailing slashes");
      AUnit.Assertions.Assert (Model.Name_Of ("b") = "b", "a name alone");
      AUnit.Assertions.Assert (Model.Child_Of ("/", "a") = "/a", "child of the root");
      AUnit.Assertions.Assert (Model.Child_Of ("/a", "b") = "/a/b", "child");
      AUnit.Assertions.Assert (Model.Child_Of ("/a/", "b") = "/a/b", "child of a path with a trailing slash");
      AUnit.Assertions.Assert
        (Model.Folded ("ReadMe" & Character'Val (16#C3#) & Character'Val (16#84#))
         = "readme" & Character'Val (16#C3#) & Character'Val (16#84#),
         "ASCII folded, UTF-8 bytes left alone");
   end Test_Paths;

   procedure Test_Stale_Entries_Dropped (T : in out Fixture) is
      pragma Unreferenced (T);
      Browser : Model.Browser;
      Old     : Natural;
   begin
      Model.Open (Browser, "/d");
      Old := Browser.Panes (Model.Current_Pane).Generation;
      Model.Reload (Browser, Model.Current_Pane);
      Model.Deliver (Browser, Model.Current_Pane, Old, Entries ("stale"), Readable => True);
      AUnit.Assertions.Assert
        (Browser.Panes (Model.Current_Pane).State = Model.Loading
         and then Browser.Panes (Model.Current_Pane).Pending,
         "entries for a replaced request are dropped");
      Give (Browser, Model.Current_Pane, "fresh");
      AUnit.Assertions.Assert
        (Model.Selected_Name (Browser.Panes (Model.Current_Pane)) = "fresh", "the newest are taken");
      Model.Deliver (Browser, Model.Current_Pane, Browser.Panes (Model.Current_Pane).Generation,
                     Entries ("again"), Readable => True);
      AUnit.Assertions.Assert
        (Model.Selected_Name (Browser.Panes (Model.Current_Pane)) = "fresh", "and only once");
   end Test_Stale_Entries_Dropped;
end Model_Tests;
