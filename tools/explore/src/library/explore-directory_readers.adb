package body Explore.Directory_Readers is
   use type Listing.Read_Outcome;

   --  The current pane first: it is what the user is looking at.
   Priority : constant array (Positive range <>) of Slot :=
     [Explore.Model.Current_Pane, Explore.Model.Preview_Pane, Explore.Model.Parent_Pane];

   protected body Board is
      function Busy return Boolean is
        (Running > 0 or else Queued > 0 or else (for some Item in Slot => Ready (Item)));

      procedure Collect (Item : Slot; Outcome : out Result; Found : out Boolean) is
      begin
         Found := Ready (Item);

         if Found then
            Outcome := Results (Item);
            Results (Item) := (others => <>);
            Ready (Item) := False;
         else
            Outcome := (others => <>);
         end if;
      end Collect;

      procedure Finish (Item : Slot; Outcome : Result) is
      begin
         Running := Running - 1;

         if Outcome.Generation = Wanted (Item) then
            Results (Item) := Outcome;
            Ready (Item) := True;
         end if;
      end Finish;

      function Is_Wanted (Item : Slot; Generation : Natural) return Boolean is
        (not Closed and then Wanted (Item) = Generation);

      procedure Shut_Down is
      begin
         Closed := True;
      end Shut_Down;

      procedure Submit (Item : Slot; Work : Request) is
      begin
         Requests (Item) := Work;

         if not Waiting (Item) then
            Waiting (Item) := True;
            Queued := Queued + 1;
         end if;

         Wanted (Item) := Work.Generation;
         --  A result for an earlier request is of no use any more.
         Ready (Item) := False;
      end Submit;

      entry Take (Item : out Slot; Work : out Request; Closed : out Boolean)
        when Board.Closed or else Queued > 0
      is
      begin
         Closed := Board.Closed;
         Item := Slot'First;
         Work := (others => <>);

         if Closed then
            return;
         end if;

         for S of Priority loop
            if Waiting (S) then
               Item := S;
               Work := Requests (S);
               Waiting (S) := False;
               Queued := Queued - 1;
               Running := Running + 1;
               return;
            end if;
         end loop;
      end Take;
   end Board;

   task body Worker is
      Item   : Slot;
      Work   : Request;
      Closed : Boolean;
   begin
      loop
         Readers.Take (Item, Work, Closed);
         exit when Closed;

         declare
            Outcome : Result := (Generation => Work.Generation, others => <>);
            Read    : Listing.Read_Outcome;

            function Replaced return Boolean is (not Readers.Is_Wanted (Item, Work.Generation));
         begin
            begin
               Listing.Read_Directory
                 (Ada.Strings.Unbounded.To_String (Work.Path), Work.Options, Outcome.Entries, Read, Replaced'Access);
            exception
               when others =>
                  Read := Listing.Read_Failed;
            end;

            if Read = Listing.Read_Complete then
               Listing.Sort (Outcome.Entries, Work.Order);
            end if;

            Outcome.Readable := Read = Listing.Read_Complete;
            Readers.Finish (Item, Outcome);
         end;
      end loop;
   end Worker;
end Explore.Directory_Readers;
