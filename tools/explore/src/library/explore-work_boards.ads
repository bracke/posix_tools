--  Handing work to worker tasks away from the screen, and its results back.
--
--  A board has a fixed set of slots, each holding at most one request waiting
--  and one result to collect. Asking a slot for something replaces whatever
--  was asked of it before, so the work outstanding never grows beyond a
--  request per slot however fast the user moves. Every request carries a
--  generation: work for one the slot no longer wants should stop at its next
--  look at Is_Wanted, and what it hands back is dropped.
--
--  Workers wait in Take, the only operation that blocks; everything else
--  returns at once, and none of the formal subprograms may block, since they
--  run inside the board's protected actions.
generic
   type Slot is (<>);
   type Request is private;
   type Result is private;

   with function Request_Generation (Work : Request) return Natural;
   with function Result_Generation (Outcome : Result) return Natural;

   --  Fold what a worker hands over into the result waiting in its slot, which
   --  is a default Result when none is.
   with procedure Merge (Held : in out Result; Outcome : Result);

   --  Of two slots with requests waiting, whether Left is taken first.
   with function Before (Left, Right : Slot) return Boolean is "<";

   --  Something a running request can be stopped through even when it is not
   --  looking at Is_Wanted, such as in the middle of reading a file; Stop is
   --  called on it once that request is no longer wanted.
   type Stopper is private;
   No_Stopper : Stopper;
   with procedure Stop (Handle : Stopper) is null;
package Explore.Work_Boards is

   type Request_Array is array (Slot) of Request;
   type Result_Array is array (Slot) of Result;
   type Flag_Array is array (Slot) of Boolean;
   type Generation_Array is array (Slot) of Natural;
   type Stopper_Array is array (Slot) of Stopper;

   protected type Board is
      --  Ask for Work in the slot, replacing any earlier request there.
      procedure Submit (Item : Slot; Work : Request);

      --  Forget what the slot was asked for, without asking for anything new.
      --  Generation zero is then the only one wanted, so it must never be used.
      procedure Cancel (Item : Slot);

      --  Wait for a request to work on, the earliest slot by Before first.
      --  Closed is True, and the worker should end, once Shut_Down has been
      --  called.
      entry Take (Item : out Slot; Work : out Request; Closed : out Boolean);

      --  Whether work for Generation in the slot is still wanted: it is what
      --  the slot was last asked for, nothing newer waits, and the board is
      --  open.
      function Is_Wanted (Item : Slot; Generation : Natural) return Boolean;

      --  The running request for Generation is stopped through Handle once it
      --  is no longer wanted -- at once if it already is not -- until Forget.
      procedure Watch (Item : Slot; Handle : Stopper; Generation : Natural);
      procedure Forget (Item : Slot);

      --  Hand over part of what a request produces, while it goes on.
      procedure Deliver (Item : Slot; Outcome : Result);

      --  Hand back the last of what a request produced, ending it.
      procedure Finish (Item : Slot; Outcome : Result);

      --  Take what the slot has to collect, if anything.
      procedure Collect (Item : Slot; Outcome : out Result; Found : out Boolean);

      --  Whether any request is waiting, running, or has a result to collect.
      function Busy return Boolean;

      --  Nothing is wanted any more, watched requests are stopped, and every
      --  worker is let out of Take.
      procedure Shut_Down;
   private
      Requests : Request_Array;
      Waiting  : Flag_Array := [others => False];
      --  How many of Waiting are set; the entry barrier reads this.
      Queued   : Natural := 0;
      --  A slot can have more than one request running, the newest wanted.
      Running  : Natural := 0;
      --  The generation each slot was last asked for.
      Wanted   : Generation_Array := [others => 0];
      Held     : Result_Array;
      Ready    : Flag_Array := [others => False];
      Watched  : Stopper_Array := [others => No_Stopper];
      Closed   : Boolean := False;
      --  What a slot holds with nothing to collect.
      Nothing  : Result;

      --  Stop the request running in the slot, if it is watched.
      procedure Stop_Watched (Item : Slot);
      --  Drop what waits in the slot, and stop the request running in it.
      procedure Supersede (Item : Slot);
      --  Keep Outcome when it is still for what the slot wants.
      procedure Accept_Outcome (Item : Slot; Outcome : Result);
   end Board;
end Explore.Work_Boards;
