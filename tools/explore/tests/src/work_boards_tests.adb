with AUnit.Assertions;
with AUnit.Test_Caller;
with Explore.Work_Boards;

package body Work_Boards_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);

   type Lane is (First, Second, Third);

   type Request is record
      Name       : Character := ' ';
      Generation : Natural := 0;
   end record;

   type Result is record
      Generation : Natural := 0;
      Count      : Natural := 0;
   end record;

   --  Stoppers are numbers; Stop marks which were stopped.
   subtype Stopper is Natural range 0 .. 9;

   Stopped : array (Stopper) of Boolean := [others => False];

   function Request_Generation (Work : Request) return Natural is (Work.Generation);
   function Result_Generation (Outcome : Result) return Natural is (Outcome.Generation);

   --  Counts add up, so that a merge shows.
   procedure Add (Held : in out Result; Outcome : Result);

   --  The last lane first, to show the order is the board's to be told.
   function Later (Left, Right : Lane) return Boolean is (Left > Right);

   procedure Stop (Handle : Stopper);

   package Boards is new Explore.Work_Boards
     (Slot               => Lane,
      Request            => Request,
      Result             => Result,
      Request_Generation => Request_Generation,
      Result_Generation  => Result_Generation,
      Merge              => Add,
      Before             => Later,
      Stopper            => Stopper,
      No_Stopper         => 0,
      Stop               => Stop);

   procedure Add (Held : in out Result; Outcome : Result) is
   begin
      Held := (Generation => Outcome.Generation, Count => Held.Count + Outcome.Count);
   end Add;

   procedure Stop (Handle : Stopper) is
   begin
      Stopped (Handle) := True;
   end Stop;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("work_boards:supersede", Test_Supersede'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("work_boards:priority", Test_Priority'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("work_boards:deliver", Test_Deliver'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("work_boards:cancellation", Test_Cancellation'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("work_boards:shut down", Test_Shut_Down'Access));
      return Result;
   end Suite;

   procedure Test_Cancellation (T : in out Fixture) is
      pragma Unreferenced (T);
      Board   : Boards.Board;
      Item    : Lane;
      Work    : Request;
      Closed  : Boolean;
      Outcome : Result;
      Found   : Boolean;
   begin
      Stopped := [others => False];
      Board.Submit (First, ('a', 1));
      Board.Take (Item, Work, Closed);
      Board.Watch (First, 4, 1);
      AUnit.Assertions.Assert (Board.Is_Wanted (First, 1) and then not Stopped (4), "wanted while running");

      Board.Cancel (First);
      AUnit.Assertions.Assert (not Board.Is_Wanted (First, 1), "a cancelled request is not wanted");
      AUnit.Assertions.Assert (Stopped (4), "and is stopped through what watches it");

      Board.Watch (First, 5, 1);
      AUnit.Assertions.Assert (Stopped (5), "watching what is not wanted stops it at once");
      Board.Forget (First);
      Stopped (5) := False;

      Board.Finish (First, (1, 1));
      Board.Collect (First, Outcome, Found);
      AUnit.Assertions.Assert (not Found and then not Board.Busy, "what it hands back is dropped");

      Board.Submit (Second, ('b', 2));
      Board.Take (Item, Work, Closed);
      Board.Watch (Second, 6, 2);
      Board.Shut_Down;
      AUnit.Assertions.Assert (Stopped (6), "shutting down stops what is watched");
      AUnit.Assertions.Assert (not Board.Is_Wanted (Second, 2), "nothing is wanted once shut down");
      AUnit.Assertions.Assert (not Stopped (5), "but not what was forgotten");
   end Test_Cancellation;

   procedure Test_Deliver (T : in out Fixture) is
      pragma Unreferenced (T);
      Board   : Boards.Board;
      Item    : Lane;
      Work    : Request;
      Closed  : Boolean;
      Outcome : Result;
      Found   : Boolean;
   begin
      Board.Submit (Second, ('a', 3));
      Board.Take (Item, Work, Closed);
      Board.Deliver (Second, (3, 2));
      Board.Deliver (Second, (3, 5));
      Board.Collect (Second, Outcome, Found);
      AUnit.Assertions.Assert (Found and then Outcome.Count = 7, "parts handed over add up");
      AUnit.Assertions.Assert (Board.Busy, "busy while the request runs");

      Board.Finish (Second, (3, 1));
      Board.Collect (Second, Outcome, Found);
      AUnit.Assertions.Assert
        (Found and then Outcome = (3, 1), "only what came since the last collection: " & Outcome.Count'Image);
      Board.Collect (Second, Outcome, Found);
      AUnit.Assertions.Assert (not Found and then not Board.Busy, "idle once collected");
   end Test_Deliver;

   procedure Test_Priority (T : in out Fixture) is
      pragma Unreferenced (T);
      Board  : Boards.Board;
      Item   : Lane;
      Work   : Request;
      Closed : Boolean;
   begin
      Board.Submit (First, ('a', 1));
      Board.Submit (Third, ('c', 1));
      Board.Submit (Second, ('b', 1));

      Board.Take (Item, Work, Closed);
      AUnit.Assertions.Assert (Item = Third and then Work.Name = 'c', "the slot Before puts first");
      Board.Take (Item, Work, Closed);
      AUnit.Assertions.Assert (Item = Second and then Work.Name = 'b', "then the next");
      Board.Take (Item, Work, Closed);
      AUnit.Assertions.Assert (Item = First and then Work.Name = 'a' and then not Closed, "then the last");
   end Test_Priority;

   procedure Test_Shut_Down (T : in out Fixture) is
      pragma Unreferenced (T);

      protected Count is
         procedure Ended;
         function Value return Natural;
      private
         Total : Natural := 0;
      end Count;

      protected body Count is
         procedure Ended is
         begin
            Total := Total + 1;
         end Ended;

         function Value return Natural is (Total);
      end Count;

      Board : aliased Boards.Board;
   begin
      declare
         task type Taker;

         task body Taker is
            Item   : Lane;
            Work   : Request;
            Closed : Boolean;
         begin
            Board.Take (Item, Work, Closed);

            if Closed then
               Count.Ended;
            end if;
         end Taker;

         Takers : array (1 .. 3) of Taker;
         pragma Unreferenced (Takers);
      begin
         delay 0.05;
         AUnit.Assertions.Assert (Count.Value = 0, "takers wait while nothing is asked for");
         Board.Shut_Down;

         for Attempt in 1 .. 500 loop
            exit when Count.Value = 3;
            delay 0.01;
         end loop;

         AUnit.Assertions.Assert (Count.Value = 3, "shutting down lets every waiting taker out, told to end");
      end;
   end Test_Shut_Down;

   procedure Test_Supersede (T : in out Fixture) is
      pragma Unreferenced (T);
      Board   : Boards.Board;
      Item    : Lane;
      Work    : Request;
      Closed  : Boolean;
      Outcome : Result;
      Found   : Boolean;
   begin
      AUnit.Assertions.Assert (not Board.Busy, "idle at first");
      Board.Submit (First, ('a', 1));
      Board.Submit (First, ('b', 2));
      Board.Take (Item, Work, Closed);
      AUnit.Assertions.Assert
        (Item = First and then Work = ('b', 2), "a slot holds only its newest request");
      AUnit.Assertions.Assert
        (Board.Is_Wanted (First, 2) and then not Board.Is_Wanted (First, 1), "only the newest is wanted");

      Board.Submit (First, ('c', 3));
      AUnit.Assertions.Assert (not Board.Is_Wanted (First, 2), "a newer request makes the running one unwanted");
      Board.Finish (First, (2, 1));
      Board.Collect (First, Outcome, Found);
      AUnit.Assertions.Assert (not Found, "the result of a superseded request is dropped");
      AUnit.Assertions.Assert (Board.Busy, "busy while the newer request waits");

      Board.Take (Item, Work, Closed);
      Board.Finish (First, (3, 1));
      Board.Submit (Second, ('d', 4));
      Board.Collect (First, Outcome, Found);
      AUnit.Assertions.Assert (Found and then Outcome = (3, 1), "another slot leaves a result alone");
   end Test_Supersede;
end Work_Boards_Tests;
