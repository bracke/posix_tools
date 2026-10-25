with Ada.Strings.Unbounded;
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

   protected type Board is
      procedure Submit (Item : Request);
      --  Stop the search running, if any, without starting another.
      procedure Stop;
      --  Take what was found since the last collection.
      procedure Collect (Outcome : out Progress; Found : out Boolean);
      function Busy return Boolean;
      procedure Shut_Down;

      entry Take (Item : out Request; Closed : out Boolean);
      function Is_Wanted (Generation : Natural) return Boolean;
      --  The search for Generation is stopped through Source, even inside a
      --  file, once it is no longer wanted -- at once if it already is not --
      --  until it is forgotten.
      procedure Watch (Source : Source_Access; Generation : Natural);
      procedure Forget;
      procedure Deliver (Batch : Listing.Entry_Vectors.Vector; Generation : Natural; Scanned : Natural);
      procedure Finish (Generation : Natural; Truncated : Boolean);
   private
      Wanted  : Request;
      Waiting : Boolean := False;
      Running : Boolean := False;
      Pending : Progress;
      Ready   : Boolean := False;
      Closed  : Boolean := False;
      --  The source of the search running, while it runs.
      Watched : Source_Access;

      --  Stop the search running, inside a file too.
      procedure Stop_Watched;
   end Board;

   task type Worker (Jobs : not null access Board);
end Explore.Search;
