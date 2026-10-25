with Ada.Strings.Unbounded;
with Explore.Model;
with Explore.Work_Boards;
with Posix_Tools.File_Operations.Listing;

--  Reading directories away from the screen.
--
--  Each pane has one slot. Asking for a pane's entries replaces whatever was
--  asked of that slot before, so the work outstanding can never grow beyond a
--  read per pane however fast the user moves; a read already running for a
--  request that has been replaced stops at its next entry. Results wait in the
--  slot until the screen collects them, newest only.
package Explore.Directory_Readers is
   package Listing renames Posix_Tools.File_Operations.Listing;

   subtype Slot is Explore.Model.Pane_Kind;

   type Request is record
      Path       : Ada.Strings.Unbounded.Unbounded_String;
      Generation : Natural := 0;
      Options    : Listing.Read_Options;
      Order      : Listing.Sort_Order;
   end record;

   type Result is record
      Generation : Natural := 0;
      Readable   : Boolean := False;
      Entries    : Listing.Entry_Vectors.Vector;
   end record;

   function Request_Generation (Work : Request) return Natural is (Work.Generation);
   function Result_Generation (Outcome : Result) return Natural is (Outcome.Generation);
   procedure Replace (Held : in out Result; Outcome : Result);

   --  The current pane first: it is what the user is looking at.
   function Before (Left, Right : Slot) return Boolean;

   package Boards is new Explore.Work_Boards
     (Slot               => Slot,
      Request            => Request,
      Result             => Result,
      Request_Generation => Request_Generation,
      Result_Generation  => Result_Generation,
      Merge              => Replace,
      Before             => Before,
      Stopper            => Boolean,
      No_Stopper         => False);

   subtype Board is Boards.Board;

   task type Worker (Readers : not null access Board);

   --  How many directories are read at once.
   Worker_Count : constant := 2;
end Explore.Directory_Readers;
