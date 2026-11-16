separate (Posix_Tools.Host_Adapters.File_System)
procedure For_Each_Follow_Chunk
  (File : in out Follow_File;
   Ok   : out Boolean)
is
   Buffer : Byte_Buffer;
   Last   : Ada.Streams.Stream_Element_Offset;
   Stop   : Boolean := False;
   Callback_Active : aliased Boolean := False;

   procedure Invoke_Action is new Invoke_Chunk_Callback
     (Callback => Action);

   procedure Reset_Position is
   begin
      File.Cursor := 0;
      File.History_Length := 0;
      File.History_Next := Follow_History_Index'First;
   end Reset_Position;

   procedure Remember
     (Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset)
   is
   begin
      for I in Buffer'First .. Last loop
         File.History (File.History_Next) := Buffer (I);
         if File.History_Length < Follow_History_Capacity then
            File.History_Length := File.History_Length + 1;
         end if;
         File.History_Next :=
           (if File.History_Next = Follow_History_Index'Last then
               Follow_History_Index'First
            else
               Follow_History_Index'Succ (File.History_Next));
      end loop;
   end Remember;

   function History_Matches return Boolean is
      use type Ada.Streams.Stream_Element;

      History_Index : Follow_History_Index :=
        (if File.History_Length = Follow_History_Capacity then
            File.History_Next
         else
            Follow_History_Index'First);
   begin
      if File.History_Length = 0 then
         return True;
      end if;

      if not Hostkit.Descriptors.Set_Position
        (File.Handle, File.Cursor - Long_Long_Integer (File.History_Length))
      then
         return False;
      end if;
      declare
         Previous : Ada.Streams.Stream_Element_Array
           (1 .. Ada.Streams.Stream_Element_Offset (File.History_Length));
         Previous_Last : Ada.Streams.Stream_Element_Offset;
         Filled : Ada.Streams.Stream_Element_Offset := Previous'First - 1;
      begin
         while Filled < Previous'Last loop
            case Hostkit.Descriptors.Read
              (File.Handle, Previous (Filled + 1 .. Previous'Last),
               Previous_Last)
            is
               when Hostkit.Descriptors.Transfer_Interrupted =>
                  null;
               when Hostkit.Descriptors.Transfer_Ok =>
                  if Previous_Last <= Filled then
                     return False;
                  end if;
                  Filled := Previous_Last;
               when others =>
                  return False;
            end case;
         end loop;

         for I in Previous'Range loop
            if Previous (I) /= File.History (History_Index) then
               return False;
            end if;
            History_Index :=
              (if History_Index = Follow_History_Index'Last then
                  Follow_History_Index'First
               else
                  Follow_History_Index'Succ (History_Index));
         end loop;
      end;
      return True;
   end History_Matches;

   function Reconcile_Position return Boolean is
   begin
      --  Verify the bytes immediately before the logical cursor: an append
      --  preserves them, while truncation or replacement does not.
      if not History_Matches then
         Reset_Position;
      end if;
      return Hostkit.Descriptors.Set_Position (File.Handle, File.Cursor);
   end Reconcile_Position;
begin
   if File.Handle_Kind = Follow_Sequential then
      Ok := Hostkit.Descriptors.Is_Valid (File.Handle);
      if not Ok then
         return;
      end if;

      loop
         if not File.Sequential_Non_Blocking then
            case Hostkit.Descriptors.Wait_For_Readable
              (File.Handle, Timeout_Ms => 0)
            is
               when Hostkit.Descriptors.Wait_Ready =>
                  null;
               when Hostkit.Descriptors.Wait_Timed_Out =>
                  exit;
               when Hostkit.Descriptors.Wait_Failed =>
                  Ok := False;
                  exit;
            end case;
         end if;

         case Hostkit.Descriptors.Read
           (File.Handle, Buffer, Last)
         is
            when Hostkit.Descriptors.Transfer_Ok =>
               Invoke_Action
                 (Buffer, Last, Stop, Callback_Active'Access);
               exit when Stop;
            when Hostkit.Descriptors.Transfer_Interrupted =>
               null;
            when Hostkit.Descriptors.Transfer_End_Of_File
               | Hostkit.Descriptors.Transfer_Would_Block =>
               exit;
            when others =>
               Ok := False;
               exit;
         end case;
      end loop;
      return;
   end if;

   Ok :=
     File.Handle_Kind = Follow_Seekable
     and then Hostkit.Descriptors.Is_Valid (File.Handle);
   if not Ok then
      return;
   end if;

   if not Reconcile_Position then
      Ok := False;
      return;
   end if;
   while not Stop loop
      case Hostkit.Descriptors.Read (File.Handle, Buffer, Last) is
         when Hostkit.Descriptors.Transfer_Ok =>
            Remember (Buffer, Last);
            File.Cursor := File.Cursor
              + Long_Long_Integer (Last - Buffer'First + 1);
            Invoke_Action (Buffer, Last, Stop, Callback_Active'Access);
         when Hostkit.Descriptors.Transfer_Interrupted =>
            null;
         when Hostkit.Descriptors.Transfer_End_Of_File =>
            exit;
         when others =>
            Ok := False;
            exit;
      end case;
   end loop;
exception
   when others =>
      --  intentional terminal exception barrier
      if Callback_Active then
         raise;
      end if;
      Ok := False;
end For_Each_Follow_Chunk;
