with Explore.Input;
with Posix_Tools.File_Operations.Listing;

--  What a key means. The bindings follow vi: hjkl to move and go in and out
--  of directories, gg and G for the ends, and a few two-key sequences that
--  start with a prefix key.
package Explore.Keymap is
   type Action is
     (No_Action,
      Quit,
      Move_Up,
      Move_Down,
      Move_Top,
      Move_Bottom,
      Half_Page_Up,
      Half_Page_Down,
      Page_Up,
      Page_Down,
      Enter_Directory,
      Leave_Directory,
      Toggle_Hidden,
      Start_Filter,
      Clear_Filter,
      Sort_Entries,
      Go_Home,
      Toggle_Mark,
      Yank,
      Cut,
      Paste,
      Paste_Links,
      Delete_Entries,
      Rename_Entry,
      Create_Entry,
      Change_Mode,
      Cancel_Job,
      Show_Jobs);

   type Command is record
      Kind       : Action := No_Action;
      --  For Sort_Entries.
      Key        : Posix_Tools.File_Operations.Listing.Sort_Key := Posix_Tools.File_Operations.Listing.By_Natural_Name;
      Descending : Boolean := False;
   end record;

   type State is private;

   procedure Translate (Self : in out State; Item : Explore.Input.Event; Result : out Command);

   --  The prefix key typed so far, for the status line; empty when none.
   function Pending (Self : State) return String;

private
   type Prefix is (No_Prefix, Go_Prefix, Sort_Prefix);

   type State is record
      Waiting : Prefix := No_Prefix;
   end record;
end Explore.Keymap;
