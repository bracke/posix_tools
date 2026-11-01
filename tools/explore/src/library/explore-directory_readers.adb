with Explore.Paths;
with Posix_Tools.Host_Adapters.File_System;

package body Explore.Directory_Readers is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type Listing.Read_Outcome;

   --  How soon each pane is read.
   Rank : constant array (Slot) of Positive :=
     [Explore.Model.Current_Pane => 1, Explore.Model.Preview_Pane => 2, Explore.Model.Parent_Pane => 3];

   function Before (Left, Right : Slot) return Boolean is (Rank (Left) < Rank (Right));

   --  Look each of Work's names up again into Entries, until Stopped.
   procedure Look_Again
     (Work    : Request;
      Entries : out Listing.Entry_Vectors.Vector;
      Stopped : not null access function return Boolean);

   procedure Look_Again
     (Work    : Request;
      Entries : out Listing.Entry_Vectors.Vector;
      Stopped : not null access function return Boolean)
   is
      Root : constant String := Ada.Strings.Unbounded.To_String (Work.Path);
   begin
      Entries.Clear;

      for Name of Work.Names loop
         exit when Stopped.all;

         declare
            Path : constant String := Explore.Paths.Child_Of (Root, Name);
         begin
            if FS.Exists (Path) or else FS.Is_Link (Path) then
               Entries.Append (Listing.Look_Up (Root, Name));
            end if;
         end;
      end loop;
   end Look_Again;

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
               if Work.Look_Again then
                  Look_Again (Work, Outcome.Entries, Replaced'Access);
                  Read := (if Replaced then Listing.Read_Stopped else Listing.Read_Complete);
               else
                  Listing.Read_Directory
                    (Ada.Strings.Unbounded.To_String (Work.Path), Work.Options, Outcome.Entries, Read,
                     Replaced'Access);
               end if;
            exception
               when others =>
                  Read := Listing.Read_Failed;
            end;

            if Read = Listing.Read_Complete and then not Work.Look_Again then
               Listing.Sort (Outcome.Entries, Work.Order);
            end if;

            Outcome.Readable := Read = Listing.Read_Complete;
            Readers.Finish (Item, Outcome);
         end;
      end loop;
   end Worker;
end Explore.Directory_Readers;
