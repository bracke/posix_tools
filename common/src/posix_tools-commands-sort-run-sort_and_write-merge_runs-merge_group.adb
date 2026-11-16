separate (Posix_Tools.Commands.Sort.Run.Sort_And_Write.Merge_Runs)
procedure Merge_Group
  (Items : in out Run_Vectors.Vector; First_Run, Last_Run : Positive)
is
   Group_Count : constant Positive := Last_Run - First_Run + 1;
   type Heap_Array is array (Positive range <>) of Positive;
   Heap      : Heap_Array (1 .. Group_Count);
   Heap_Last : Natural := 0;

   procedure Advance (Index : Positive);
   function Comes_Before (Left, Right : Positive) return Boolean;
   procedure Add_To_Heap (Index : Positive);
   procedure Restore_Heap;

   function Comes_Before (Left, Right : Positive) return Boolean is
      Left_Ref  : constant Run_Vectors.Constant_Reference_Type := Items.Constant_Reference (Left);
      Right_Ref : constant Run_Vectors.Constant_Reference_Type := Items.Constant_Reference (Right);
   begin
      if Direct_Text then
         if Options.Sorting.Global.Reverse_Order then
            if Left_Ref.Element.all.Line > Right_Ref.Element.all.Line then
               return True;
            elsif Left_Ref.Element.all.Line < Right_Ref.Element.all.Line then
               return False;
            end if;
         else
            if Left_Ref.Element.all.Line < Right_Ref.Element.all.Line then
               return True;
            elsif Left_Ref.Element.all.Line > Right_Ref.Element.all.Line then
               return False;
            end if;
         end if;
      else
         declare
            Compared : constant Integer :=
              Sort_Keys.Compare
                (Comparator, Left_Ref.Element.all.Prepared, Right_Ref.Element.all.Prepared);
         begin
            if Compared < 0 then
               return True;
            elsif Compared > 0 then
               return False;
            end if;
         end;
      end if;
      --  Each pass groups adjacent runs, so a lower index is earlier input on
      --  a key tie and preserves stable-sort order.
      return Left < Right;
   end Comes_Before;

   procedure Add_To_Heap (Index : Positive) is
      Position : Positive;
   begin
      Heap_Last := Heap_Last + 1;
      Position := Heap_Last;
      Heap (Position) := Index;
      while Position > 1 loop
         declare
            Parent : constant Positive := Position / 2;
            Saved  : Positive;
         begin
            exit when not Comes_Before (Heap (Position), Heap (Parent));
            Saved := Heap (Parent);
            Heap (Parent) := Heap (Position);
            Heap (Position) := Saved;
            Position := Parent;
         end;
      end loop;
   end Add_To_Heap;

   procedure Restore_Heap is
      Position : Positive := 1;
   begin
      while Position * 2 <= Heap_Last loop
         declare
            Child : Positive := Position * 2;
            Saved : Positive;
         begin
            if Child < Heap_Last
              and then Comes_Before (Heap (Child + 1), Heap (Child))
            then
               Child := Child + 1;
            end if;
            exit when not Comes_Before (Heap (Child), Heap (Position));
            Saved := Heap (Position);
            Heap (Position) := Heap (Child);
            Heap (Child) := Saved;
            Position := Child;
         end;
      end loop;
   end Restore_Heap;

   procedure Advance (Index : Positive) is
      Ref : constant Run_Vectors.Reference_Type := Items.Reference (Index);
      Run : Run_State renames Ref.Element.all;
   begin
      if Run.Buffer = null then
         Run.Buffer := new Byte_Buffer;
      end if;
      Run.Line := Null_Unbounded_String;
      Run.Available := False;
      loop
         if Run.Next <= Run.Last then
            declare
               Start : constant Ada.Streams.Stream_Element_Offset := Run.Next;
            begin
               while Run.Next <= Run.Last
                 and then Run.Buffer.all (Run.Next) /= Ada.Streams.Stream_Element (10)
               loop
                  Run.Next := Run.Next + 1;
               end loop;
               declare
                  Span_Length : constant Natural := Natural (Run.Next - Start);
                  Text        : String (1 .. Span_Length);
               begin
                  for I in Start .. Run.Next - 1 loop
                     Text (Natural (I - Start) + 1) := Character'Val (Run.Buffer.all (I));
                  end loop;
                  Append (Run.Line, Text);
               end;
               if Run.Next <= Run.Last then
                  Run.Next := Run.Next + 1;
                  Run.Available := True;
                  if not Direct_Text then
                     Run.Prepared := Sort_Keys.Prepare_Line (Comparator, Run.Line);
                  end if;
                  exit;
               end if;
            end;
         end if;
         if Run.At_End then
            exit;
         end if;
         declare
            Outcome : constant Storage.Read_Outcome :=
              Storage.Read_Next (Run.Store.all, Run.Buffer.all, Run.Last);
         begin
            if Outcome /= Storage.Read_Complete then
               Storage_Error (Outcome);
               exit;
            end if;
         end;
         if Run.Last < Run.Buffer.all'First then
            Run.At_End := True;
         end if;
         Run.Next := Run.Buffer.all'First;
      end loop;
   end Advance;
begin
   for I in First_Run .. Last_Run loop
      declare
         Outcome : constant Storage.Prepare_Outcome :=
           Storage.Prepare_For_Read (Items.Element (I).Store.all);
      begin
         if Outcome /= Storage.Prepare_Complete then
            Storage_Error (Outcome);
            exit;
         end if;
      end;
      Advance (I);
      if Items.Element (I).Available then
         Add_To_Heap (I);
      end if;
   end loop;

   while Ok and then Heap_Last > 0 loop
      declare
         Best : constant Positive := Heap (1);
         Ref  : constant Run_Vectors.Constant_Reference_Type := Items.Constant_Reference (Best);
      begin
         Take (Ref.Element.all.Line, Ref.Element.all.Prepared);
         Advance (Best);
         if Items.Element (Best).Available then
            Restore_Heap;
         else
            Heap (1) := Heap (Heap_Last);
            Heap_Last := Heap_Last - 1;
            if Heap_Last > 0 then
               Restore_Heap;
            end if;
         end if;
      end;
   end loop;
end Merge_Group;
