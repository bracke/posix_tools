separate (Posix_Tools.Commands.Sort.Run.Sort_And_Write)
procedure Spill is
   Run           : Run_State;
   Create_Status : Storage.Create_Outcome;
   Finish_Status : Storage.Finish_Outcome;
   Buffer        : Spill_Byte_Buffer;
   Buffered_Last : Ada.Streams.Stream_Element_Offset :=
     Buffer'First - 1;

   procedure Flush_Buffer;
   procedure Append_Text (Text : String);

   procedure Flush_Buffer is
   begin
      if Ok and then Buffered_Last >= Buffer'First then
         declare
            Outcome : constant Storage.Append_Outcome :=
              Storage.Append (Run.Store.all, Buffer, Buffered_Last);
         begin
            if Outcome /= Storage.Append_Complete then
               Storage_Error (Outcome);
            end if;
         end;
         Buffered_Last := Buffer'First - 1;
      end if;
   end Flush_Buffer;

   procedure Append_Text (Text : String) is
   begin
      for Ch of Text loop
         exit when not Ok;
         Buffered_Last := Buffered_Last + 1;
         Buffer (Buffered_Last) :=
           Ada.Streams.Stream_Element (Character'Pos (Ch));
         if Buffered_Last = Buffer'Last then
            Flush_Buffer;
         end if;
      end loop;
   end Append_Text;
begin
   if Lines.Is_Empty or else not Ok then
      return;
   end if;
   Sort_Keys.Sort_Lines (Lines, Options.Sorting);
   Run.Store := new Storage.Store;
   Create_Status :=
     Storage.Create (Run.Store.all, Posix_Tools.Numbers.Count'Last);
   if Create_Status /= Storage.Create_Complete then
      Storage_Error (Create_Status);
   end if;
   for Line of Lines loop
      exit when not Ok;
      Append_Text (Line);
      Append_Text ([1 => LF]);
   end loop;
   Flush_Buffer;
   if Ok then
      Finish_Status := Storage.Finish_Writing (Run.Store.all);
      if Finish_Status /= Storage.Finish_Complete then
         Storage_Error (Finish_Status);
      end if;
   end if;
   if Ok then
      Runs.Append (Run);
      Run.Store := null;
   elsif Run.Store /= null then
      Release_Run (Run);
   end if;
   Lines.Clear;
   Resident_Bytes := 0;
exception
   when others =>
      Release_Run (Run);
      raise;
end Spill;
