separate (Posix_Tools.Commands.Sort.Run.Sort_And_Write)
procedure Merge_Runs is
   Merge_Fan_In : constant := 32;
   Output      : Posix_Tools.Host_Adapters.Output_Files.Output_File;
   Output_Open : Boolean := False;
   Pending     : Unbounded_String;
   Previous_Text : Unbounded_String;
   Direct_Text : constant Boolean := Sort_Keys.Uses_Direct_Text_Key (Comparator);

   procedure Flush;
   procedure Write_Direct (Text : String);
   procedure Emit (Item : Sort_Keys.Prepared_Line);
   procedure Emit (Line : Unbounded_String);

   procedure Write_Direct (Text : String) is
   begin
      if not Ok then
         return;
      elsif Output_Open then
         Posix_Tools.Host_Adapters.Output_Files.Write (Output, Text, Ok);
      else
         Context.Put (Text);
         Ok := not Context.Output_Failed;
      end if;
   end Write_Direct;

   procedure Flush is
   begin
      if Length (Pending) = 0 or else not Ok then
         return;
      end if;
      Write_Direct (To_String (Pending));
      Pending := Null_Unbounded_String;
   end Flush;

   procedure Emit (Item : Sort_Keys.Prepared_Line) is
      Item_Length : constant Natural := Sort_Keys.Original_Length (Item);
   begin
      if Item_Length >= Output_Chunk_Size then
         Flush;
         declare
            First : Positive := 1;
         begin
            while First <= Item_Length loop
               declare
                  Last : constant Natural := Natural'Min (Item_Length, First + Output_Chunk_Size - 1);
               begin
                  Write_Direct (Sort_Keys.Original_Slice (Item, First, Last));
                  First := Last + 1;
               end;
            end loop;
         end;
         Write_Direct ([1 => LF]);
      else
         Append (Pending, Sort_Keys.Original (Item));
         Append (Pending, LF);
         if Length (Pending) >= Output_Chunk_Size then
            Flush;
         end if;
      end if;
   end Emit;

   procedure Emit (Line : Unbounded_String) is
      Item_Length : constant Natural := Length (Line);
   begin
      if Item_Length >= Output_Chunk_Size then
         Flush;
         declare
            First : Positive := 1;
         begin
            while First <= Item_Length loop
               declare
                  Last : constant Natural := Natural'Min (Item_Length, First + Output_Chunk_Size - 1);
               begin
                  Write_Direct (Slice (Line, First, Last));
                  First := Last + 1;
               end;
            end loop;
         end;
         Write_Direct ([1 => LF]);
      else
         Append (Pending, Line);
         Append (Pending, LF);
         if Length (Pending) >= Output_Chunk_Size then
            Flush;
         end if;
      end if;
   end Emit;

   generic
      with procedure Take (Line : Unbounded_String; Prepared : Sort_Keys.Prepared_Line);
   procedure Merge_Group
     (Items : in out Run_Vectors.Vector; First_Run, Last_Run : Positive);

   procedure Merge_Group
     (Items : in out Run_Vectors.Vector; First_Run, Last_Run : Positive)
   is separate;

   procedure Merge_Pass (Items : in out Run_Vectors.Vector) is separate;

   procedure Final_Take (Line : Unbounded_String; Prepared : Sort_Keys.Prepared_Line) is
   begin
      if Direct_Text then
         if not Options.Sorting.Unique or else not Have_Previous or else Line /= Previous_Text then
            Emit (Line);
            if Options.Sorting.Unique then
               Previous_Text := Line;
               Have_Previous := True;
            end if;
         end if;
      elsif not Options.Sorting.Unique
        or else not Have_Previous
        or else not Sort_Keys.Keys_Equal (Comparator, Previous, Prepared)
      then
         Emit (Prepared);
         Previous := Prepared;
         Have_Previous := True;
      end if;
   end Final_Take;

   procedure Final_Merge is new Merge_Group (Final_Take);
begin
   while Ok and then Natural (Runs.Length) > Merge_Fan_In loop
      Merge_Pass (Runs);
   end loop;

   if Ok and then Length (Options.Output_Path) > 0 then
      Posix_Tools.Host_Adapters.Output_Files.Open
        (Output, To_String (Options.Output_Path), False, Ok);
      Output_Open := Ok;
   end if;
   if Ok and then not Runs.Is_Empty then
      Final_Merge (Runs, Runs.First_Index, Runs.Last_Index);
   end if;
   Flush;
   if Output_Open then
      declare
         Closed : Boolean;
      begin
         Posix_Tools.Host_Adapters.Output_Files.Close (Output, Closed);
         Ok := Ok and Closed;
      end;
   end if;
end Merge_Runs;
