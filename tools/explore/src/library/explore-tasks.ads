with Ada.Strings.Unbounded;
with Explore.Model;
with Posix_Tools.File_Operations.Listing;

--  Reading directories away from the screen.
--
--  Each pane has one slot. Asking for a pane's entries replaces whatever was
--  asked of that slot before, so the work outstanding can never grow beyond a
--  read per pane however fast the user moves; a read already running for a
--  request that has been replaced stops at its next entry. Results wait in the
--  slot until the screen collects them, newest only.
package Explore.Tasks is
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

   type Request_Array is array (Slot) of Request;
   type Result_Array is array (Slot) of Result;
   type Flag_Array is array (Slot) of Boolean;
   type Generation_Array is array (Slot) of Natural;

   protected type Board is
      --  Ask for a slot's directory to be read, replacing any earlier request.
      procedure Submit (Item : Slot; Work : Request);

      --  Wait for a request to work on. Closed is True, and the worker should
      --  end, once Shut_Down has been called.
      entry Take (Item : out Slot; Work : out Request; Closed : out Boolean);

      --  Whether Generation is still what the slot was last asked for.
      function Is_Wanted (Item : Slot; Generation : Natural) return Boolean;

      --  Hand back what a request produced; dropped unless it is still wanted.
      procedure Finish (Item : Slot; Outcome : Result);

      --  Take the slot's result, if one is waiting.
      procedure Collect (Item : Slot; Outcome : out Result; Found : out Boolean);

      --  Whether any request is waiting, running, or has a result to collect.
      function Busy return Boolean;

      procedure Shut_Down;
   private
      Requests : Request_Array;
      Waiting  : Flag_Array := [others => False];
      --  How many of Waiting are set; the entry barrier reads this.
      Queued   : Natural := 0;
      Running  : Natural := 0;
      --  The generation each slot was last asked for.
      Wanted   : Generation_Array := [others => 0];
      Results  : Result_Array;
      Ready    : Flag_Array := [others => False];
      Closed   : Boolean := False;
   end Board;

   task type Worker (Jobs : not null access Board);

   --  How many directories are read at once.
   Worker_Count : constant := 2;
end Explore.Tasks;
