package body Explore.Directory_Readers is
   use type Listing.Read_Outcome;

   --  How soon each pane is read.
   Rank : constant array (Slot) of Positive :=
     [Explore.Model.Current_Pane => 1, Explore.Model.Preview_Pane => 2, Explore.Model.Parent_Pane => 3];

   function Before (Left, Right : Slot) return Boolean is (Rank (Left) < Rank (Right));

   procedure Replace (Held : in out Result; Outcome : Result) is
   begin
      Held := Outcome;
   end Replace;

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
