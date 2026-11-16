separate (Posix_Tools.Commands.File_Helpers.Tailing.Copy_Line_Suffix)
procedure Scan_Buffer
  (Buffer      : Ada.Streams.Stream_Element_Array;
   Buffer_Last : Ada.Streams.Stream_Element_Offset)
is
   First : Ada.Streams.Stream_Element_Offset := Buffer'First;
begin
   if Buffer_Last < Buffer'First then
      return;
   end if;

   for I in Buffer'First .. Buffer_Last loop
      if Spill_Needed then
         Append_To_Store (Buffer (First .. Buffer_Last), Buffer_Last);
         return;
      end if;

      if Buffer (I) = Ada.Streams.Stream_Element (10) then
         Append
           (Current,
            Posix_Tools.Streams.Bytes.To_String
              (Buffer (First .. I), I));
         First := I + 1;
         if Posix_Tools.Numbers.Count (Length (Current)) >
           Context.Tail_Memory_Threshold
         then
            Start_Spill;
         else
            Keep_Current;
         end if;
         if Spill_Needed and then First <= Buffer_Last then
            Append_To_Store
              (Buffer (First .. Buffer_Last), Buffer_Last);
            return;
         end if;
         exit when not Ok;
      end if;
   end loop;

   if not Spill_Needed and then First <= Buffer_Last then
      Append
        (Current,
         Posix_Tools.Streams.Bytes.To_String
           (Buffer (First .. Buffer_Last), Buffer_Last));
      if Posix_Tools.Numbers.Count (Length (Current)) >
        Context.Tail_Memory_Threshold
      then
         Start_Spill;
      end if;
   end if;
end Scan_Buffer;
