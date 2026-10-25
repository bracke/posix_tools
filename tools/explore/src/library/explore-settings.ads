with Ada.Containers.Ordered_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Explore.Keymap;
with Explore.Launch;
with Explore.Previews;
with Explore.Themes;
with Posix_Tools.File_Operations.Listing;

--  The user's configuration, read from a TOML file, and the bookmarks kept
--  from one session to the next.
--
--  The configuration has an [options] table, a [keys] table of key bindings,
--  a [theme] table of styles by role, and arrays of tables [[open]] and
--  [[preview]] of openers and previewers. Whatever it leaves out keeps its
--  default. A part that cannot be read is left out and reported, and the
--  rest is used: a mistake in one binding does not cost the user the others.
--
--  This package only reads and writes text; Explore.Settings.Storage reads
--  and writes the files.
package Explore.Settings is
   type Settings is record
      Show_Hidden : Boolean := False;
      Sort_Key    : Posix_Tools.File_Operations.Listing.Sort_Key :=
        Posix_Tools.File_Operations.Listing.By_Natural_Name;
      Descending  : Boolean := False;
      Thumbnails  : Boolean := True;
      Colors      : Explore.Themes.Theme := Explore.Themes.Default_Theme;
      Keys        : Explore.Keymap.State;
      Openers     : Explore.Launch.Opener_Vectors.Vector;
      Previewers  : Explore.Previews.Rule_Vectors.Vector;
   end record;

   type Problem_Kind is
     (Unreadable_File,   --  The file exists and cannot be read.
      Syntax_Error,      --  It is not TOML; Line is where it stops being.
      Unknown_Setting,   --  A key explore does not know.
      Bad_Value);        --  A value of the wrong type or out of range.

   type Problem is record
      Kind  : Problem_Kind := Bad_Value;
      --  The setting, as a dotted path such as "keys.ctrl-x", or the file.
      Where : Ada.Strings.Unbounded.Unbounded_String;
      --  For a syntax error, the line of the file it is on, from 1. It is a
      --  number rather than text so that the word for "line" is the
      --  reader's language.
      Line  : Natural := 0;
   end record;

   package Problem_Vectors is new Ada.Containers.Vectors (Positive, Problem);

   --  Read the configuration in Text.
   procedure Parse (Text : String; Into : out Settings; Problems : out Problem_Vectors.Vector);

   --  Where the configuration is: config.toml in the explore directory of
   --  Config_Home, the value of XDG_CONFIG_HOME, or of Home's .config when
   --  that is empty. Empty when both are.
   function Configuration_Path (Config_Home, Home : String) return String;

   --  Where bookmarks are kept: the file bookmarks in the explore directory
   --  of State_Home, the value of XDG_STATE_HOME, or of Home's .local/state.
   function Bookmarks_Path (State_Home, Home : String) return String;

   package Bookmark_Maps is new Ada.Containers.Ordered_Maps
     (Character, Ada.Strings.Unbounded.Unbounded_String, "<", Ada.Strings.Unbounded."=");

   --  Bookmarks as they are kept: a line for each, its letter, a space, and
   --  its directory. A line that is not one is skipped.
   function Bookmarks_Image (Marks : Bookmark_Maps.Map) return String;
   function Bookmarks_Value (Text : String) return Bookmark_Maps.Map;
end Explore.Settings;
