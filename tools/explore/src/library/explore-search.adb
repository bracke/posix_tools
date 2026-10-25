with Ada.Strings.Fixed;
with Explore.Model;
with Greplib.Collected;
with Greplib.Options;
with Greplib.Paths;
with Greplib.Patterns;
with Greplib.Results;
with Posix_Tools.Text.Glob;

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
   function Contains (Set : Greplib.Patterns.Compiled_Pattern_Set; Path : String) return Boolean;

   protected body Board is
      function Busy return Boolean is (Waiting or else Running or else Ready);

      procedure Collect (Outcome : out Progress; Found : out Boolean) is
      begin
         Found := Ready;
         Outcome := Pending;
         Pending.Found.Clear;
         Ready := False;
      end Collect;

      procedure Deliver (Batch : Listing.Entry_Vectors.Vector; Generation : Natural; Scanned : Natural) is
      begin
         if Generation = Wanted.Generation then
            Pending.Generation := Generation;
            Pending.Found.Append (Batch);
            Pending.Scanned := Scanned;
            Ready := True;
         end if;
      end Deliver;

      procedure Finish (Generation : Natural; Truncated : Boolean) is
      begin
         Running := False;

         if Generation = Wanted.Generation then
            Pending.Generation := Generation;
            Pending.Finished := True;
            Pending.Truncated := Truncated;
            Ready := True;
         end if;
      end Finish;

      function Is_Wanted (Generation : Natural) return Boolean is
        (not Closed and then not Waiting and then Generation = Wanted.Generation);

      procedure Shut_Down is
      begin
         Closed := True;
      end Shut_Down;

      procedure Stop is
      begin
         --  No generation is ever zero, so the running search is no longer wanted.
         Wanted.Generation := 0;
         Waiting := False;
         Ready := False;
         Pending := (others => <>);
      end Stop;

      procedure Submit (Item : Request) is
      begin
         Wanted := Item;
         Waiting := True;
         Ready := False;
         Pending := (Generation => Item.Generation, others => <>);
      end Submit;

      entry Take (Item : out Request; Closed : out Boolean) when Board.Closed or else Waiting is
      begin
         Closed := Board.Closed;
         Item := Wanted;
         Waiting := False;
         Running := not Closed;
      end Take;
   end Board;

   function Compile (Pattern : String) return Greplib.Patterns.Compiled_Pattern_Set is
      List : Greplib.Patterns.Pattern_List;
   begin
      Greplib.Patterns.Append (List, Greplib.Patterns.Fixed_String_Pattern (Pattern));
      return Greplib.Patterns.Compile (List, (Case_Insensitive => True, others => <>));
   end Compile;

   function Contains (Set : Greplib.Patterns.Compiled_Pattern_Set; Path : String) return Boolean is
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
         Result);
      return Greplib.Results.Selected_Record_Count (Greplib.Results.Summary (Result.Outcome)) > 0;
   exception
      when others =>
         return False;
   end Contains;

   function Name_Matches (Pattern, Name : String) return Boolean is
     (if (for some C of Pattern => C in '*' | '?' | '[')
      then Posix_Tools.Text.Glob.Matches (Pattern, Name)
      else Ada.Strings.Fixed.Index (Explore.Model.Folded (Name), Explore.Model.Folded (Pattern)) > 0);

   task body Worker is
      Item   : Request;
      Closed : Boolean;
   begin
      loop
         Jobs.Take (Item, Closed);
         exit when Closed;

         declare
            Pattern   : constant String := Unbounded.To_String (Item.Pattern);
            Set       : constant Greplib.Patterns.Compiled_Pattern_Set := Compile (Pattern);
            Batch     : Listing.Entry_Vectors.Vector;
            Count     : Natural := 0;
            Scanned   : Natural := 0;
            Truncated : Boolean := False;

            function Stopped return Boolean is (not Jobs.Is_Wanted (Item.Generation) or else Truncated);

            procedure Walk (Directory, Below : String; Depth : Natural);

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
                     Path : constant String := Explore.Model.Child_Of (Directory, Name);
                     Hit  : constant Boolean :=
                       (case Item.Kind is
                          when By_Name => Name_Matches (Pattern, Name),
                          when By_Content =>
                            Found.Kind = Listing.Regular_Entry and then not Found.Is_Link
                            and then Contains (Set, Path));
                  begin
                     if Hit then
                        if Count = Max_Results then
                           Truncated := True;
                        else
                           Count := Count + 1;
                           Batch.Append ((Found with delta Name => Unbounded.To_Unbounded_String (Below & Name)));

                           if Natural (Batch.Length) >= Batch_Size then
                              Jobs.Deliver (Batch, Item.Generation, Scanned);
                              Batch.Clear;
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
                  Jobs.Deliver (Batch, Item.Generation, Scanned);
                  Batch.Clear;
               end if;
            end Walk;
         begin
            begin
               Walk (Unbounded.To_String (Item.Root), "", 0);
            exception
               when others =>
                  --  What was found stands; the search ends as if cut short.
                  Truncated := True;
            end;

            Jobs.Finish (Item.Generation, Truncated);
         end;
      end loop;
   end Worker;
end Explore.Search;
