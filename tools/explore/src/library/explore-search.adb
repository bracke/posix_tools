with Ada.Strings.Fixed;
with Explore.Paths;
with Greplib.Collected;
with Greplib.Options;
with Greplib.Paths;
with Greplib.Patterns;
with Greplib.Results;

package body Explore.Search is
   package Unbounded renames Ada.Strings.Unbounded;

   use type Greplib.Wide_Count;
   use type Listing.Entry_Kind;
   use type Listing.Read_Outcome;

   --  A batch is handed over once it holds this many results, and at the end
   --  of every directory.
   Batch_Size : constant := 64;

   --  The compiled form of a content search's pattern.
   function Compile (Pattern : String) return Greplib.Patterns.Compiled_Pattern_Set;

   --  Whether the file at Path holds what Set matches. Binary files are left
   --  out.
   function Contains
     (Set     : Greplib.Patterns.Compiled_Pattern_Set;
      Path    : String;
      Stopped : Greplib.Cancellation.Cancellation_Token) return Boolean;

   function Compile (Pattern : String) return Greplib.Patterns.Compiled_Pattern_Set is
      List : Greplib.Patterns.Pattern_List;
   begin
      Greplib.Patterns.Append (List, Greplib.Patterns.Fixed_String_Pattern (Pattern));
      return Greplib.Patterns.Compile (List, (Case_Insensitive => True, others => <>));
   end Compile;

   function Contains
     (Set     : Greplib.Patterns.Compiled_Pattern_Set;
      Path    : String;
      Stopped : Greplib.Cancellation.Cancellation_Token) return Boolean
   is
      Result : Greplib.Collected.Collected_Result;
   begin
      if not Greplib.Patterns.Is_Usable (Set) then
         return False;
      end if;

      Greplib.Collected.Search_File
        (Greplib.Paths.To_Path (Path),
         Set,
         (Mode                     => Greplib.Options.Count_Selected_Records,
          Maximum_Selected_Records => 1,
          Binary_Detection         => Greplib.Options.Detect_Null_Byte,
          On_Binary                => Greplib.Options.Skip_Source,
          others                   => <>),
         (others => <>),
         Result,
         Stopped);
      return Greplib.Results.Selected_Record_Count (Greplib.Results.Summary (Result.Outcome)) > 0;
   exception
      when others =>
         return False;
   end Contains;

   procedure Merge (Held : in out Progress; Outcome : Progress) is
   begin
      Held.Generation := Outcome.Generation;
      Held.Found.Append (Outcome.Found);
      Held.Scanned := Outcome.Scanned;
      Held.Finished := Outcome.Finished;
      Held.Truncated := Outcome.Truncated;
   end Merge;

   function Name_Matches (Pattern, Name : String) return Boolean is
     (if (for some C of Pattern => C in '*' | '?' | '[')
      then Explore.Paths.Glob_Matches (Pattern, Name)
      else Ada.Strings.Fixed.Index (Explore.Paths.Folded (Name), Explore.Paths.Folded (Pattern)) > 0);

   procedure Stop_Source (Source : Source_Access) is
   begin
      Source.Request;
   end Stop_Source;

   task body Worker is
      Taken      : Slot;
      Item       : Request;
      Closed     : Boolean;
   begin
      loop
         Jobs.Take (Taken, Item, Closed);
         exit when Closed;

         declare
            --  Stopped from the board, so that a file being read is left at
            --  once, however large.
            Source    : aliased Greplib.Cancellation.Cancellation_Source;
            Token     : constant Greplib.Cancellation.Cancellation_Token := Greplib.Cancellation.Token (Source);
            Pattern   : constant String := Unbounded.To_String (Item.Pattern);
            Set       : constant Greplib.Patterns.Compiled_Pattern_Set := Compile (Pattern);
            Batch     : Listing.Entry_Vectors.Vector;
            Count     : Natural := 0;
            Scanned   : Natural := 0;
            Truncated : Boolean := False;

            function Stopped return Boolean is (not Jobs.Is_Wanted (Taken, Item.Generation) or else Truncated);

            --  Deliver the batch, and start the next.
            procedure Hand_Over;

            procedure Walk (Directory, Below : String; Depth : Natural);

            procedure Hand_Over is
            begin
               Jobs.Deliver (Taken, (Generation => Item.Generation, Found => Batch, Scanned => Scanned, others => <>));
               Batch.Clear;
            end Hand_Over;

            procedure Walk (Directory, Below : String; Depth : Natural) is
               Entries : Listing.Entry_Vectors.Vector;
               Outcome : Listing.Read_Outcome;
            begin
               Listing.Read_Directory
                 (Directory, (Include_Hidden => Item.Include_Hidden, With_Status => True), Entries, Outcome,
                  Stopped'Access);
               Scanned := Scanned + 1;

               if Outcome /= Listing.Read_Complete then
                  return;
               end if;

               for Found of Entries loop
                  exit when Stopped;

                  declare
                     Name : constant String := Unbounded.To_String (Found.Name);
                     Path : constant String := Explore.Paths.Child_Of (Directory, Name);
                     Hit  : constant Boolean :=
                       (case Item.Kind is
                          when By_Name => Name_Matches (Pattern, Name),
                          when By_Content =>
                            Found.Kind = Listing.Regular_Entry and then not Found.Is_Link
                            and then Contains (Set, Path, Token));
                  begin
                     if Hit then
                        if Count = Max_Results then
                           Truncated := True;
                        else
                           Count := Count + 1;
                           Batch.Append ((Found with delta Name => Unbounded.To_Unbounded_String (Below & Name)));

                           if Natural (Batch.Length) >= Batch_Size then
                              Hand_Over;
                           end if;
                        end if;
                     end if;

                     --  Links are not followed, so a tree that links to itself ends.
                     if Found.Kind = Listing.Directory_Entry and then not Found.Is_Link and then Depth < Max_Depth then
                        Walk (Path, Below & Name & "/", Depth + 1);
                     end if;
                  end;
               end loop;

               if not Batch.Is_Empty then
                  Hand_Over;
               end if;
            end Walk;
         begin
            Jobs.Watch (Taken, Source'Unchecked_Access, Item.Generation);

            begin
               Walk (Unbounded.To_String (Item.Root), "", 0);
            exception
               when others =>
                  --  What was found stands; the search ends as if cut short.
                  Truncated := True;
            end;

            --  The source goes with this block; the board must not reach it.
            Jobs.Forget (Taken);

            Jobs.Finish
              (Taken,
               (Generation => Item.Generation,
                Scanned    => Scanned,
                Finished   => True,
                Truncated  => Truncated,
                others     => <>));
         end;
      end loop;
   end Worker;
end Explore.Search;
