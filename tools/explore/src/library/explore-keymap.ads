with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Explore.Input;
with Posix_Tools.File_Operations.Listing;

--  What a key means. The bindings follow vi: hjkl to move and go in and out
--  of directories, gg and G for the ends, and a few two-key sequences that
--  start with a prefix key. Keys bound in the configuration come first: a
--  key or a two-key sequence bound there means what it is bound to, and a key
--  bound to nothing means nothing.
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
      Show_Jobs,
      New_Tab,
      Close_Tab,
      Previous_Tab,
      Next_Tab,
      Switch_Tab,
      Go_Back,
      Go_Forward,
      Jump_To_Path,
      Set_Bookmark,
      Go_Bookmark,
      Visual_Mode,
      Search_Names,
      Search_Contents,
      Open_Entries,
      Shell_Command,
      Spawn_Shell,
      Copy_Path,
      Copy_Directory,
      Copy_Name);

   type Command is record
      Kind       : Action := No_Action;
      --  For Sort_Entries.
      Key        : Posix_Tools.File_Operations.Listing.Sort_Key := Posix_Tools.File_Operations.Listing.By_Natural_Name;
      Descending : Boolean := False;
      --  The tab for Switch_Tab, from 1.
      Number     : Natural := 0;
      --  The bookmark for Set_Bookmark and Go_Bookmark.
      Letter     : Character := ' ';
   end record;

   --  The command an action name stands for, as the configuration writes it:
   --  the action's name in lower case, such as "move_down", followed for the
   --  actions that take one by a colon and an argument: a sort key with an
   --  optional "_descending" for sort_entries, a tab number for switch_tab,
   --  and a letter or digit for set_bookmark and go_bookmark. "none" stands
   --  for no action.
   procedure Parse_Command (Text : String; Result : out Command; Ok : out Boolean);

   --  One key as the configuration writes it: a character, "space", or a
   --  named key -- enter, tab, backspace, esc, up, down, left, right, home,
   --  end, pageup, pagedown, insert, delete, f1 to f12 -- after any of the
   --  prefixes "ctrl-" and "alt-".
   type Key_Spec is record
      Key     : Explore.Input.Key_Kind := Explore.Input.Character_Key;
      Code    : Wide_Wide_Character := ' ';
      Number  : Natural := 0;
      Control : Boolean := False;
      Alt     : Boolean := False;
   end record;

   --  A binding's keys: one, or two separated by a space.
   procedure Parse_Keys (Text : String; First, Second : out Key_Spec; Has_Second : out Boolean; Ok : out Boolean);

   type State is private;

   --  Bind Keys to the command Action names, ahead of the default bindings.
   --  Ok is False, and nothing is bound, when either cannot be read.
   procedure Bind (Self : in out State; Keys, Action_Name : String; Ok : out Boolean);

   procedure Translate (Self : in out State; Item : Explore.Input.Event; Result : out Command);

   --  The prefix key typed so far, for the status line; empty when none.
   function Pending (Self : State) return String;

private
   type Prefix is (No_Prefix, Go_Prefix, Sort_Prefix, Bookmark_Prefix, Jump_Prefix, Copy_Prefix, Bound_Prefix);

   type Binding is record
      First      : Key_Spec;
      Second     : Key_Spec;
      Has_Second : Boolean := False;
      Result     : Command;
      --  The first key as written, for the status line while it waits.
      Shown      : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Binding_Vectors is new Ada.Containers.Vectors (Positive, Binding);

   type State is record
      Waiting  : Prefix := No_Prefix;
      Bindings : Binding_Vectors.Vector;
      --  The bound first key of a sequence, while Waiting is Bound_Prefix.
      Held     : Explore.Input.Event;
      Held_Shown : Ada.Strings.Unbounded.Unbounded_String;
   end record;
end Explore.Keymap;
