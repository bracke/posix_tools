separate (Posix_Tools.Commands.File_Helpers.Tailing.Copy_Line_Suffix)
function Find_Store_Line_Start
  (Start : out Posix_Tools.Numbers.Count) return Boolean
is
   Buffer : Bulk_Byte_Buffer;
   Last : Ada.Streams.Stream_Element_Offset;
   Next : Posix_Tools.Numbers.Count := 1;
   Line_Feeds : Posix_Tools.Numbers.Count := 0;
   Lines_In_Store : Posix_Tools.Numbers.Count;
   To_Skip : Posix_Tools.Numbers.Count;
   Last_Byte : Ada.Streams.Stream_Element := 0;
   Size : constant Posix_Tools.Numbers.Count :=
     Posix_Tools.Host_Adapters.Temporary_Storage.Size (Store);
begin
   Start := 1;
   if Size = 0 then
      return True;
   end if;

   --  Count lines in one forward pass. The store is bounded well below
   --  Count'Last, so Line_Feeds cannot overflow.
   while Next <= Size loop
      if not Posix_Tools.Host_Adapters.Temporary_Storage.Read
        (Store, Next, Buffer, Last)
      then
         return False;
      end if;
      exit when Last < Buffer'First;
      for I in Buffer'First .. Last loop
         if Buffer (I) = Ada.Streams.Stream_Element (10) then
            Line_Feeds :=
              Line_Feeds + Posix_Tools.Numbers.Count (1);
         end if;
      end loop;
      Last_Byte := Buffer (Last);
      Next :=
        Next
        + Posix_Tools.Numbers.Count
            (Last - Buffer'First + Ada.Streams.Stream_Element_Offset (1));
   end loop;

   Lines_In_Store :=
     Line_Feeds
     + (if Last_Byte = Ada.Streams.Stream_Element (10) then 0 else 1);
   if Lines >= Lines_In_Store then
      return True;
   end if;

   To_Skip := Lines_In_Store - Lines;
   Next := 1;
   Line_Feeds := 0;
   while Next <= Size loop
      if not Posix_Tools.Host_Adapters.Temporary_Storage.Read
        (Store, Next, Buffer, Last)
      then
         return False;
      end if;
      exit when Last < Buffer'First;
      for I in Buffer'First .. Last loop
         if Buffer (I) = Ada.Streams.Stream_Element (10) then
            Line_Feeds :=
              Line_Feeds + Posix_Tools.Numbers.Count (1);
            if Line_Feeds = To_Skip then
               Start :=
                 Next
                 + Posix_Tools.Numbers.Count (I - Buffer'First)
                 + Posix_Tools.Numbers.Count (1);
               return True;
            end if;
         end if;
      end loop;
      Next :=
        Next
        + Posix_Tools.Numbers.Count
            (Last - Buffer'First + Ada.Streams.Stream_Element_Offset (1));
   end loop;

   return False;
end Find_Store_Line_Start;
