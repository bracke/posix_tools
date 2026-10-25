with Ada.Strings.Unbounded;
with Explore.Work_Boards;
with Greplib.Cancellation;
with Posix_Tools.File_Operations.Listing;

--  Finding entries below a directory: by name, as a glob when the pattern has
--  *, ?, or [ in it and as a substring when it has not, either way regardless
--  of case; or by content, the files whose text contains the pattern
--  regardless of case.
--
--  A search walks the tree away from the screen, without following links,
--  and hands its results over in batches as it finds them, so the first show
--  at once however large the tree. A newer search replaces it, and it stops
--  at its next entry.
package Explore.Search is
   package Listing renames Posix_Tools.File_Operations.Listing;

   type Search_Kind is (By_Name, By_Content);

   type Request is record
      Root           : Ada.Strings.Unbounded.Unbounded_String;
      Pattern        : Ada.Strings.Unbounded.Unbounded_String;
      Kind           : Search_Kind := By_Name;
      Include_Hidden : Boolean := False;
      Generation     : Natural := 0;
   end record;

   --  Results found so far: each entry's Name is its path below the root.
   type Progress is record
      Generation : Natural := 0;
      Found      : Listing.Entry_Vectors.Vector;
      --  Directories read so far, and whether the walk has ended.
      Scanned    : Natural := 0;
      Finished   : Boolean := False;
      --  More was found than a search keeps.
      Truncated  : Boolean := False;
   end record;

   Max_Results : constant := 10_000;
   Max_Depth   : constant := 64;

   --  Whether Name matches Pattern as a name search takes it.
   function Name_Matches (Pattern, Name : String) return Boolean;

   --  How a search that reads a file is stopped in the middle of it.
   type Source_Access is access all Greplib.Cancellation.Cancellation_Source;

   --  Stop the search reading from Source, inside a file too.
   procedure Stop_Source (Source : Source_Access);

   --  The board has one slot: the search of the current pane.
   type Slot is (Only);

   function Request_Generation (Work : Request) return Natural is (Work.Generation);
   function Result_Generation (Outcome : Progress) return Natural is (Outcome.Generation);
   --  What a batch adds to what was found before it.
   procedure Merge (Held : in out Progress; Outcome : Progress);

   --  A search no longer wanted is stopped through its source, even inside a
   --  file. Cancel stops the search running without starting another.
   package Boards is new Explore.Work_Boards
     (Slot               => Slot,
      Request            => Request,
      Result             => Progress,
      Request_Generation => Request_Generation,
      Result_Generation  => Result_Generation,
      Merge              => Merge,
      Stopper            => Source_Access,
      No_Stopper         => null,
      Stop               => Stop_Source);

   subtype Board is Boards.Board;

   task type Worker (Jobs : not null access Board);
end Explore.Search;
