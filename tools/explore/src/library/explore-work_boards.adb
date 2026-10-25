package body Explore.Work_Boards is

   protected body Board is
      procedure Accept_Outcome (Item : Slot; Outcome : Result) is
      begin
         if Result_Generation (Outcome) = Wanted (Item) then
            Merge (Held (Item), Outcome);
            Ready (Item) := True;
         end if;
      end Accept_Outcome;

      function Busy return Boolean is
        (Running > 0 or else Queued > 0 or else (for some Item in Slot => Ready (Item)));

      procedure Cancel (Item : Slot) is
      begin
         Wanted (Item) := 0;

         if Waiting (Item) then
            Waiting (Item) := False;
            Queued := Queued - 1;
         end if;

         Supersede (Item);
      end Cancel;

      procedure Collect (Item : Slot; Outcome : out Result; Found : out Boolean) is
      begin
         Found := Ready (Item);
         Outcome := Held (Item);
         Held (Item) := Nothing;
         Ready (Item) := False;
      end Collect;

      procedure Deliver (Item : Slot; Outcome : Result) is
      begin
         Accept_Outcome (Item, Outcome);
      end Deliver;

      procedure Finish (Item : Slot; Outcome : Result) is
      begin
         Running := Running - 1;
         Accept_Outcome (Item, Outcome);
      end Finish;

      procedure Forget (Item : Slot) is
      begin
         Watched (Item) := No_Stopper;
      end Forget;

      function Is_Wanted (Item : Slot; Generation : Natural) return Boolean is
        (not Closed and then not Waiting (Item) and then Wanted (Item) = Generation);

      procedure Shut_Down is
      begin
         Closed := True;

         for Item in Slot loop
            Stop_Watched (Item);
         end loop;
      end Shut_Down;

      procedure Stop_Watched (Item : Slot) is
      begin
         if Watched (Item) /= No_Stopper then
            Stop (Watched (Item));
         end if;
      end Stop_Watched;

      procedure Submit (Item : Slot; Work : Request) is
      begin
         Requests (Item) := Work;
         Wanted (Item) := Request_Generation (Work);

         if not Waiting (Item) then
            Waiting (Item) := True;
            Queued := Queued + 1;
         end if;

         Supersede (Item);
      end Submit;

      procedure Supersede (Item : Slot) is
      begin
         --  A result for an earlier request is of no use any more.
         Held (Item) := Nothing;
         Ready (Item) := False;
         Stop_Watched (Item);
      end Supersede;

      entry Take (Item : out Slot; Work : out Request; Closed : out Boolean) when Board.Closed or else Queued > 0 is
         Chosen : Boolean := False;
      begin
         Closed := Board.Closed;
         Item := Slot'First;

         if not Closed then
            for S in Slot loop
               if Waiting (S) and then (not Chosen or else Before (S, Item)) then
                  Item := S;
                  Chosen := True;
               end if;
            end loop;

            Waiting (Item) := False;
            Queued := Queued - 1;
            Running := Running + 1;
         end if;

         Work := Requests (Item);
      end Take;

      procedure Watch (Item : Slot; Handle : Stopper; Generation : Natural) is
      begin
         Watched (Item) := Handle;

         if not Is_Wanted (Item, Generation) then
            Stop_Watched (Item);
         end if;
      end Watch;
   end Board;
end Explore.Work_Boards;
