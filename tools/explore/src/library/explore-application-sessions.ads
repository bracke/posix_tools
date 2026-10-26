with Ada.Containers.Ordered_Maps;
with Ada.Strings.Unbounded;
with Explore.Image_Cache;
with Explore.Input;
with Explore.Jobs;
with Explore.Keymap;
with Explore.Launch;
with Explore.Model;
with Explore.Previews;
with Explore.Protocol;
with Explore.Render;
with Explore.Screen;
with Explore.Search;
with Explore.Settings;
with Explore.String_Vectors;
with Explore.Tabs;
with Explore.Words;
with Posix_Tools.File_Operations;
with Posix_Tools.Host_Adapters.File_Watches;
with Posix_Tools.Host_Adapters.Signals;
with Posix_Tools.Host_Adapters.Terminal_IO;

--  What one session knows, shared by the parts of the application: the
--  terminal, the workers, the configuration, what the user is in the middle
--  of, and what is shown. Also the few things every part does to it: saying
--  something in the status line, and going into and out of a mode.
private package Explore.Application.Sessions is
   package Terminal_IO renames Posix_Tools.Host_Adapters.Terminal_IO;
   package Unbounded renames Ada.Strings.Unbounded;

   --  What the next key means.
   type Interaction_Mode is
     (Browsing,
      Filtering,         --  Typing the filter.
      Renaming,          --  Typing a new name for the selected entry.
      Creating,          --  Typing the name of a file, or of a directory with a slash.
      Changing_Mode,     --  Typing permissions, octal or symbolic.
      Jumping,           --  Typing a path to go to.
      Finding_Names,     --  Typing a name or glob to search for.
      Finding_Text,      --  Typing text to search files for.
      Shelling,          --  Typing a shell command to run on the entries.
      --  Renaming, changing modes and shell commands act on Pending: the
      --  entries as they were when asked, whatever a reload does meanwhile.
      Confirming_Delete, --  y deletes the entries in Pending, anything else does not.
      Confirming_Quit,   --  y quits and stops the jobs still running or waiting.
      Answering,         --  A running job asks about a target that exists.
      Viewing_Jobs);     --  The jobs panel is open.

   --  The modes that type a line under a label, which Enter commits.
   subtype Prompt_Mode is Interaction_Mode range Renaming .. Shelling;

   --  The modes that wait for a key to answer a question.
   subtype Question_Mode is Interaction_Mode range Confirming_Delete .. Answering;

   --  The panes whose directories are watched for changes.
   type Watched_Pane is (Watch_Parent, Watch_Current);

   Pane_Of : constant array (Watched_Pane) of Explore.Model.Pane_Kind :=
     [Watch_Parent => Explore.Model.Parent_Pane, Watch_Current => Explore.Model.Current_Pane];

   type Watch_Array is array (Watched_Pane) of Posix_Tools.Host_Adapters.File_Watches.Watch;
   type Path_Array is array (Watched_Pane) of Unbounded.Unbounded_String;
   type Generation_Array is array (Explore.Model.Pane_Kind) of Natural;

   type Board_Access is access all Explore.Jobs.Board;
   type Preview_Board_Access is access all Explore.Previews.Board;
   type Search_Board_Access is access all Explore.Search.Board;

   package Name_Maps is new Ada.Containers.Ordered_Maps (Natural, Unbounded.Unbounded_String, "<", Unbounded."=");

   --  The terminal, and what it shows.
   type Terminal_State is record
      In_Tmux     : Boolean := False;
      Size        : Terminal_IO.Window_Size;
      Decoder     : Explore.Input.Decoder;
      Identity    : Explore.Protocol.Identity;
      --  Its settings as they were found, for handing it to another program
      --  and back.
      Saved_Mode  : Terminal_IO.Saved_Mode;
      --  A cell's size in pixels, from the terminal's size reports.
      Cell_Width  : Positive := 8;
      Cell_Height : Positive := 16;
      Images      : Explore.Image_Cache.Cache;
      --  What the terminal shows, and what the next frame should show.
      Shown       : Explore.Screen.Grid;
      Wanted      : Explore.Screen.Grid;
      --  Repaint every cell, not only those that changed.
      Repaint     : Boolean := True;
   end record;

   --  The workers, and what has been asked of them.
   type Worker_State is record
      --  The boards outlive the session's use of them: Run_Session clears
      --  these before it leaves the block that declares them.
      Operations : Board_Access;
      Previewer  : Preview_Board_Access;
      Searcher   : Search_Board_Access;
      --  The jobs as last seen, and the board's version then.
      Last_Job    : Explore.Jobs.Snapshot;
      Job_Version : Explore.Jobs.Version_Number := 0;
      --  A job's question that waits for a prompt to be done with: once it
      --  is, the question is asked, though nothing on the board changed.
      Question_Waiting : Boolean := False;
      --  The target the question on screen is about. A job that was answered
      --  can ask again before the screen shows it; a key meant for the old
      --  question must not answer the new one.
      Asked_About : Unbounded.Unbounded_String;
      --  The generation last handed to the readers, per pane.
      Submitted  : Generation_Array := [others => 0];
      Watches    : Watch_Array;
      Watching   : Path_Array;
      --  The file whose preview was asked for, and for which generation.
      Previewing : Unbounded.Unbounded_String;
      Preview_Generation : Natural := 0;
      --  The generation of the search last started; its results go to the
      --  current pane while it shows them.
      Search_Generation : Natural := 0;
      Search_Found      : Natural := 0;
   end record;

   --  What the session was started with.
   type Configuration is record
      Directory  : Unbounded.Unbounded_String;
      Home       : Unbounded.Unbounded_String;
      Locale     : Unbounded.Unbounded_String;
      Words      : Explore.Words.Word_Set;
      Openers    : Explore.Launch.Opener_Vectors.Vector;
      Previewers : Explore.Previews.Rule_Vectors.Vector;
      Thumbnails : Boolean := True;
      --  Where bookmarks are kept, empty when nowhere.
      Marks_File : Unbounded.Unbounded_String;
      --  Where the directory is written on quitting, and where opened
      --  entries are written instead of being opened; empty when not asked.
      Cwd_File     : Unbounded.Unbounded_String;
      Chooser_File : Unbounded.Unbounded_String;
   end record;

   --  What the user is in the middle of.
   type Interaction_State is record
      --  The one record of the mode: the frame's flags are made from it.
      Mode      : Interaction_Mode := Browsing;
      --  The mode a question returns to once it is answered.
      Resume    : Interaction_Mode := Browsing;
      Keys      : Explore.Keymap.State;
      --  Yanked or cut entries, waiting to be pasted.
      Clipboard : Explore.String_Vectors.Vector;
      Cutting   : Boolean := False;
      --  The entries a prompt or a delete was opened for.
      Pending   : Explore.String_Vectors.Vector;
      Bookmarks : Explore.Settings.Bookmark_Maps.Map;
   end record;

   type Session is record
      Terminal    : Terminal_State;
      Workers     : Worker_State;
      Config      : Configuration;
      Interaction : Interaction_State;

      Browser : Explore.Model.Browser;
      Tabs    : Explore.Tabs.Tab_Set;
      Frame   : Explore.Render.Frame_Context;
      Dirty   : Boolean := True;
      --  Owner and group names by number, looked up once each.
      Users   : Name_Maps.Map;
      Groups  : Name_Maps.Map;

      Quit      : Boolean := False;
      --  Whether the terminal stopped taking output, or giving input: the
      --  session ends, and not as one the user ended.
      Terminal_Lost : Boolean := False;
      --  The signal that ended the session, when one did.
      Ended_By  : Posix_Tools.Host_Adapters.Signals.Signal := Posix_Tools.Host_Adapters.Signals.Terminate_Signal;
      Signalled : Boolean := False;
   end record;

   function Write (Text : String) return Boolean renames Terminal_IO.Write;

   --  Write Text to the terminal; when it no longer takes output, the
   --  session ends.
   procedure Send (State : in out Session; Text : String);

   --  End the session because the terminal is gone.
   procedure Lose_Terminal (State : in out Session);

   --  Show Text in the status line until the next key, as news or as an
   --  error.
   procedure Say (State : in out Session; Text : String);
   procedure Warn (State : in out Session; Text : String);

   --  Show Error about Path in the status line.
   procedure Complain (State : in out Session; Path : String; Error : Posix_Tools.File_Operations.Operation_Error);

   --  Start typing a line for Mode under Label, beginning with Initial.
   procedure Open_Prompt
     (State   : in out Session;
      Mode    : Prompt_Mode;
      Label   : Unbounded.Unbounded_String;
      Initial : String := "");

   --  Ask Question, waiting for a key in Mode. Once it is answered, the
   --  filter is typed on if it was being typed, and the jobs panel stays
   --  open if it was open; otherwise browsing resumes.
   procedure Ask (State : in out Session; Mode : Question_Mode; Question : String);

   --  Go back from the mode the session is in: from a question to what it
   --  interrupted, and from anything else to browsing.
   procedure Leave_Mode (State : in out Session);

   --  Set the frame's flags for what the mode shows: a prompt, the filter
   --  being typed, or the jobs panel -- the last two also beneath a question
   --  that interrupted them.
   procedure Show_Mode (State : in out Session);
end Explore.Application.Sessions;
